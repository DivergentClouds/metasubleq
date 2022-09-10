const std = @import("std");

var memory_size : usize = 0x10000;
var word_size : u8 = 2;
var max_size : usize = 0;

const Tokens = enum {
    left_paren,
    right_paren,
    left_bracket,
    right_bracket,
    left_brace,
    right_brace,
    left_angle,
    right_angle,

    colon,
    semicolon,
    hash,
    comma,
    caret,
    star,
    slash,
    plus,
    minus,
    bang,
    period,
    
    // murmur3_32 hash
    identifier,
    number,
    
    eof,
};

const Token = struct {
    token_type: Tokens,
    value: i64,
    line_number: usize,
    column_number: usize,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len == 1) {
        printHelp(args[0]);
        return error.BadArgs;
    } else if (args.len == 4) { // memory size has been specified
        memory_size = std.fmt.parseInt(usize, args[3], 0) catch
            return error.BadMemorySize;

        switch (memory_size) {
            3 ... 0x100 => word_size = 1,
            0x101 ... 0x10000 => word_size = 2,
            0x10001 ... 0x1000000 => word_size = 3,
            0x1000001 ... 0x100000000 => word_size = 4,
            else => {
                std.log.err("Memory must be between 3 bytes and 4 gibibytes",
                    .{});
                return error.BadMemorySize;
            }
        }
    } else if (args.len != 3) {
        printHelp(args[0]);
        return error.BadArgs;
    }

    var input_file = try std.fs.cwd().openFile(args[1], .{});
    defer input_file.close();

    var input_slice = try std.fs.cwd().readFileAlloc(allocator, args[1],
        (try input_file.metadata()).size());
    defer allocator.free(input_slice);

    const token_list = try scanTokens(allocator, input_slice) orelse return;
    defer allocator.free(token_list);

    // TODO: only allocate as needed to avoid an unnecessary 4GiB buffer
    var output_buffer = try allocator.alloc(u8, memory_size);
    defer allocator.free(output_buffer);

}

fn scanTokens(allocator: std.mem.Allocator, source: []u8) !?[]Token {
    var start: usize = 0; // start of current token
    var current: usize = 0; // index of current character
    var line: usize = 1; // the current line number
    var line_begin: usize = 0; // index at the start of the line
    var column: usize = 0; // start of the current token within the line

    var token_list = std.ArrayList(Token).init(allocator);
    errdefer token_list.deinit();

    var stderr = std.io.getStdErr().writer();

    while (current < source.len) {
        var token = scanToken(&start, &current, &line, &line_begin, &column, source)
            catch |err| {
                try stderr.print("Error on line {d}, column {d}:\n\n",
                    .{line, column + 1}); // columns are 1-indexed
                try stderr.print("{s}\n",
                    .{source[line_begin .. countUntilNewline(line_begin, source)]});
                try stderr.writeByteNTimes(' ', column);
                try stderr.writeAll("^\n");

                switch (err) {
                    error.UnknownCharacter =>
                        try stderr.writeAll("Invalid character in source code\n"),
                    error.Overflow =>
                        try stderr.writeAll("Number too large\n"),
                    error.InvalidCharacter =>
                        try stderr.writeAll("Invalid character in number\n"),
                    else => {
                        try stderr.print("{!}\n", .{err});
                        try stderr.writeAll(
                            "If you have gotten this improperly formatted error, please create an issue if one has not already been created."
                        );
                    }
                }
                token_list.deinit();
                return null;
            }
            orelse {
                continue;
            };
    
        try token_list.append(token);
    }
    
    return token_list.toOwnedSlice();
}

fn scanToken(
    start: *usize, current: *usize, line: *usize, line_begin: *usize,
    column: *usize, source: []u8)
    !?Token {
    
    start.* = current.*;
    
    defer {
        start.* += 1; 
        // this may not equal start.* due to multi-character tokens
        current.* += 1; 
        column.* = start.* - line_begin.* -| 1;
    }

    if (current.* == source.len) return null;
    
    const token = source[current.*];
    switch (token) {
        '(' => return createToken(.left_paren, token, line.*, column.*),
        ')' => return createToken(.right_paren, token, line.*, column.*),
        '[' => return createToken(.left_bracket, token, line.*, column.*),
        ']' => return createToken(.right_bracket, token, line.*, column.*),
        '{' => return createToken(.left_brace, token, line.*, column.*),
        '}' => return createToken(.right_brace, token, line.*, column.*),
        '<' => return createToken(.left_angle, token, line.*, column.*),
        '>' => return createToken(.right_angle, token, line.*, column.*),
        ':' => return createToken(.colon, token, line.*, column.*),
        '#' => return createToken(.hash, token, line.*, column.*),
        ',' => return createToken(.comma, token, line.*, column.*),
        '^' => return createToken(.caret, token, line.*, column.*),
        '*' => return createToken(.star, token, line.*, column.*),
        '/' => return createToken(.slash, token, line.*, column.*),
        '+' => return createToken(.plus, token, line.*, column.*),
        '-' => return createToken(.minus, token, line.*, column.*),
        '!' => return createToken(.bang, token, line.*, column.*),
        '.' => return createToken(.period, token, line.*, column.*),
        'A' ... 'Z', 'a' ... 'z', '_' =>
            return scanIdentifier(start.*, current, line.*, column.*, source),
        '0' ... '9' => return try scanNumber(start.*, current, line.*, column.*, source),
        ';' => {
            scanComment(current, source);
            return null;
        },
        '\n' => {
            line.* += 1;
            line_begin.* = current.* + 1;
            return null;
        },
        else => {
            if (!std.ascii.isSpace(token)) {
                return error.UnknownCharacter;
            }
            return null;
        }
        
    }
}

fn countUntilNewline(start: usize, source: []u8) usize {
    var count: usize = start;

    while (source[count] != '\n' and count < source.len) {
        count += 1;
    }
    
    return count;
}

fn scanComment(current: *usize, source: []u8) void {
    while (source[current.* + 1] != '\n' and current.* < source.len) {
        current.* += 1;
    }
}

fn scanIdentifier(start: usize, current: *usize, line: usize, column: usize, source: []u8) Token {
    var valid_character = true;
    
    while (valid_character and current.* < source.len) {
        var current_character = source[current.*];
        switch (current_character) {
            // we know it doesn't start with 0-9 due to where this is called
            'A' ... 'Z', 'a' ... 'z', '0' ... '9', '_' => current.* += 1,
            else => valid_character = false,
        }
    }
    
    return createToken(
        .identifier,
        std.hash.Murmur3_32.hash(source[start .. current.*]),
        line,
        column
    );
}

fn scanNumber(start: usize, current: *usize, line: usize, column: usize, source: []u8) !Token {
   var valid_character = true;
    
    while (valid_character and current.* < source.len) {
        var current_character = source[current.*];
        switch (current_character) {
            // we know it starts with 0-9 due to where this is called
            '0' ... '9', 'x', 'b', 'o' => current.* += 1,
            else => valid_character = false,
        }
    }
    
    return createToken(
        .number,
        // this will be checked to see if it is within bounds during parsing
        try std.fmt.parseInt(i64, source[start .. current.*], 0),
        line,
        column,
    );
}

fn createToken(token: Tokens, value: i64, line: usize, column: usize) Token {
    return Token {
        .token_type = token,
        .value = value,
        .line_number = line,
        .column_number = column,
    };
}

fn printHelp(arg0 : []u8) void {
    std.log.err(\\Usage:
        \\{s} <input> <output> [memory size]
        \\Memory size is 65536 by default
        \\Word size is implied by memory size
        \\
        ,.{arg0});
}
