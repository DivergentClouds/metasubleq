const std = @import("std");

var mem_size : usize = 0x10000;
var word_size : u8 = 2;
var max_size : usize = 0;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len == 1) {
        printHelp(args);
        return;
    } else if (args.len == 4) {
        mem_size = std.fmt.parseInt(usize, args[3], 0);

        switch (mem_size) {
            3 ... 0x100 => word_size = 1,
            0x101 ... 0x10000 => word_size = 2,
            0x10001 ... 0x1000000 => word_size = 3,
            0x1000001 ... 0x100000000 => word_size = 4,
            else => {
                std.log.err("Memory must be between 3 bytes and 4 gibibytes", .{});
                return Error.badMemorySize;
            }
        }
    }

    var in_file = try std.fs.cwd().openFile(args[1], .{});
    defer in_file.close();

    var in_stat = try in_file.metadata();
    var in_mem = try std.fs.cwd().readFileAlloc(allocator, args[1], in_stat.size());
    defer allocator.free(in_mem);

    var out_buf = allocator.alloc(u8, mem_size);
}

fn printHelp(args : [][]u8) void {
    std.log.info(\\Usage:\n{s} <input> <output> [memory size]\n
        \\Memory size is 65536 by default\n
        \\Word size is implied by memory size
        ,.{args[0]});
}
