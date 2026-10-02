const std = @import("std");

pub fn display(writer: *std.Io.Writer) !void {
    try writer.writeAll(
        \\BNF Grammar
        \\
        \\<graph> → start <plot_stmts> end
        \\
        \\<plot_stmts> → <plot>
        \\             | <plot> ; <plot_stmts>
        \\
        \\<plot> → bar <x><y>,<y>
        \\        | line <x><y>,<x><y>
        \\        | grid <x><y>
        \\        | fill <x><y>
        \\
        \\<x> → a | b | c | d | e | f | g | h | i | j
        \\
        \\<y> → 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9
        \\
    );
}
