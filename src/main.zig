const std = @import("std");
const grammar = @import("grammar.zig");

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    // Buffers used for terminal input and output.
    var input_buffer: [1024]u8 = undefined;
    var output_buffer: [4096]u8 = undefined;

    // Create the standard input reader.
    var stdin_reader = std.Io.File.stdin().reader(
        io,
        &input_buffer,
    );

    const stdin = &stdin_reader.interface;

    // Create the standard output writer.
    var stdout_writer = std.Io.File.stdout().writer(
        io,
        &output_buffer,
    );

    const stdout = &stdout_writer.interface;

    while (true) {
        // ========================================
        // Display the BNF grammar
        // ========================================

        try stdout.writeAll(
            \\========================================
            \\       CMPS3111 PROJECT 2
            \\========================================
            \\
        );

        try grammar.display(stdout);

        try stdout.writeAll(
            \\========================================
            \\
        );

        try stdout.flush();
        // ========================================
        // Prompt for an input sentence
        // ========================================

        try stdout.writeAll(
            "Enter an input string (or STOP to terminate): ",
        );

        try stdout.flush();

        // Read one complete line from the user.
        const input = stdin.takeDelimiterExclusive('\n') catch |err| {
            if (err == error.EndOfStream) {
                break;
            }

            return err;
        };

        // Remove the carriage return that can appear with
        // Windows-style CRLF input.
        const sentence = std.mem.trim(
            u8,
            input,
            "\r",
        );

        // ========================================
        // Exact STOP check
        // ========================================

        if (std.mem.eql(u8, sentence, "STOP")) {
            try stdout.writeAll(
                "\nProgram terminated.\n",
            );

            try stdout.flush();
            break;
        }

        // ========================================
        // Temporary placeholder
        // ========================================

        try stdout.print(
            "\nYou entered: {s}\n",
            .{sentence},
        );

        try stdout.writeAll(
            "Parser not implemented yet.\n\n",
        );

        try stdout.flush();
    }
}
