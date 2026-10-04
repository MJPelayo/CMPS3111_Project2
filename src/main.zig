const std = @import("std");
const grammar = @import("grammar.zig");
const lexer = @import("lexer.zig");
const parser = @import("parser.zig");
const derivation = @import("derivation.zig");
const parse_tree = @import("parse_tree.zig");
const graphics = @import("graphics.zig");

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var input_buffer: [1024]u8 = undefined;
    var output_buffer: [4096]u8 = undefined;

    var stdin_reader = std.Io.File.stdin().reader(
        io,
        &input_buffer,
    );

    const stdin = &stdin_reader.interface;

    var stdout_writer = std.Io.File.stdout().writer(
        io,
        &output_buffer,
    );

    const stdout = &stdout_writer.interface;

    while (true) {
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

        try stdout.writeAll(
            "Enter an input string (or STOP to terminate): ",
        );

        try stdout.flush();

        const input = try stdin.takeDelimiter('\n') orelse break;

        const sentence = std.mem.trim(
            u8,
            input,
            "\r",
        );

        if (std.mem.eql(u8, sentence, "STOP")) {
            try stdout.writeAll(
                "\nProgram terminated.\n",
            );

            try stdout.flush();
            break;
        }

        if (sentence.len == 0) {
            try stdout.writeAll(
                "\nError: Empty input.\n\n",
            );

            try stdout.flush();
            continue;
        }

        var tokens: [100]lexer.Token = undefined;

        const token_count = lexer.tokenize(
            sentence,
            &tokens,
        ) catch |err| {
            try stdout.print(
                "\nLEXICAL ERROR: {s}\n\n",
                .{@errorName(err)},
            );

            try stdout.flush();
            continue;
        };

        var graph_parser = parser.Parser.init(
            tokens[0..token_count],
        );

        graph_parser.parseGraph() catch |err| {
            try stdout.print(
                "\nSYNTAX ERROR: {s}\n\n",
                .{@errorName(err)},
            );

            try stdout.flush();
            continue;
        };

        try stdout.writeAll(
            "\nLEFTMOST DERIVATION\n",
        );

        try stdout.writeAll(
            "----------------------------------------\n",
        );

        derivation.displayGraphDerivation(
            stdout,
            tokens[0..token_count],
        ) catch |err| {
            try stdout.print(
                "\nDERIVATION ERROR: {s}\n\n",
                .{@errorName(err)},
            );

            try stdout.flush();
            continue;
        };

        try stdout.writeAll(
            "----------------------------------------\n",
        );

        try stdout.writeAll(
            "\nPARSE TREE\n",
        );

        try stdout.writeAll(
            "----------------------------------------\n",
        );

        parse_tree.displayGraphParseTree(
            stdout,
            tokens[0..token_count],
        ) catch |err| {
            try stdout.print(
                "\nPARSE TREE ERROR: {s}\n\n",
                .{@errorName(err)},
            );

            try stdout.flush();
            continue;
        };

        try stdout.writeAll(
            "----------------------------------------\n",
        );

        try stdout.writeAll(
            "\nInput accepted.\n",
        );

        try stdout.writeAll(
            "Opening graphics window...\n\n",
        );

        try stdout.flush();

        graphics.showTestWindow();
    }
}
