------------
|Metasubleq|
------------
-----------------------------
|Designed by DivergentClouds|
-----------------------------


Subleq:

 Subleq is a computer architecture with only one instruction
 Due to the fact that there is only one instruction opcodes are not needed
 There is no distinction between code and data
 Code can self modify

 An instruction takes the form:
   A B C
 Where the contents of address A are subtracted from the contents of address B
   and the result is stored in address B, if the result is less than or equal
   to 0 then branch to address C
 That is:
   *B = *B - *A;
   if (*B <= 0) {
	 goto C;
   }


Macros:

 Square brackets indicate a macro
 A colon after the parameters indicates macro definition
 A macro may take an arbitary number of arguments
 The format for defining a macro is [name param1 param2 ...: code]
 To access an argument use its name in the code section

 The format for using a macro is [name arg1 arg2 ...]

 The content of a macro is in its own namespace

 Macros may be called from within other macros

 Note that macros are inserted directly into your code and are not jumped to


Labels:

 A label marks the address it was defined at
 To define a label type the label name followed by a colon
 For example:
   name:
 Referencing the address of a label is done by using its name
 For example:
  name

Variables:

 Variables are a special case of label that are defined in curly brackets
 Variables are stored in memory directly after code
 Variables take the form of a name followed by a colon followed by 1 or more
   values
 For example:
   {name: value1 value2 ...}

 Referencing the address of a variable is done by using its name
 Variables may only be accessed within the namespace they were defined in
 Variables may be overwritten from within the namespace in which they were
   defined


Special Characters:

 #
   Word size in bytes

 .
   The location of the start of the current instruction in memory

 >
   The location of the start of the next instruction in memory

 <
   The location of the start of the previous instruction in memory


Expressions:

 Expressions are compiletime mathematical operations
 Expressions are contained within parentheses

 Expressions follow regular order of operations:
   Parentheses
   Exponentiation
   Multiplication/Division
   Addition/Subtraction
 In case of ambiguity expressions are evaluated left to right

 Expressions may contain any value

 Valid operations are:

   ^
     Exponentiation
   *
     Multiplication
   /
     Integer Division (Floored)
   +
     Addition
   -
     Subtraction

 Example:

   (> + # * 3)
   This is equal to the address of the start of the instruction after the next
   instruction
 
Location Editing:

 An expression or number followed by a colon means that further code is
 stored starting at that location

Comments:

 Comments are started by a semicolon and last until the end of the line

Imports:

 Additional files may be imported via the ! symbol at the start of a line
 For example:
   !name path/to/file

 Anything after the name on that line is counted as part of the file path

 Macros and global variables from that file can then be accessed as
 [name!macro arg1 arg2 ...] or name!variable
 
 Imports may not be accessed outside of the file that imported them

Notes:

 Metasubleq is mostly whitespace insensitive
   Imports and comments last until the end of a line and tabs are not allowed
 Metasubleq is case sensitive
 Names are of the form [_a-zA-Z][_a-zA-Z0-9]*

 A value is a number, label reference, variable, expression or special character

 Names may not collide with any other name in their own namespace
   or the global namespace
   (aside from variable redefinition)
 Macros are part of the global namespace
 Parameters are part of the namespace of the relevant macro
 Variables are part of the namespace they were defined in
 Label names are part of the namespace they were defined in
