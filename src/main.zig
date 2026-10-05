const std = @import("std");
const grammar = @import("grammar.zig");
const lexer = @import("lexer.zig");
const parser = @import("parser.zig");
const derivation = @import("derivation.zig");
const parse_tree = @import("parse_tree.zig");
const graphics = @import("graphics.zig");
const plot = @import("plot.zig");

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
        // ----------------------------------------------------
        // Display the BNF and input prompt.
        // ----------------------------------------------------

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

        const input =
            try stdin.takeDelimiter('\n') orelse break;

        const sentence = std.mem.trim(
            u8,
            input,
            "\r",
        );

        // ----------------------------------------------------
        // STOP command.
        // STOP must be entered exactly in uppercase.
        // ----------------------------------------------------

        if (std.mem.eql(u8, sentence, "STOP")) {
            try stdout.writeAll(
                "\nProgram terminated.\n",
            );

            try stdout.flush();
            break;
        }

        // ----------------------------------------------------
        // Incorrect capitalization of STOP.
        // ----------------------------------------------------

        if (isStopCommandWithWrongCase(sentence)) {
            try displayStopCaseError(
                stdout,
                sentence,
            );

            try stdout.flush();

            try pauseBeforeNextRun(
                stdin,
                stdout,
            );

            try clearTerminal(stdout);

            continue;
        }

        // ----------------------------------------------------
        // Empty input.
        // ----------------------------------------------------

        if (sentence.len == 0) {
            try stdout.writeAll(
                "\nINPUT INVALID\n\n",
            );

            try stdout.writeAll(
                "Error 1:\n",
            );

            try stdout.writeAll(
                "The input cannot be empty.\n\n",
            );

            try stdout.flush();

            try pauseBeforeNextRun(
                stdin,
                stdout,
            );

            try clearTerminal(stdout);

            continue;
        }

        // ----------------------------------------------------
        // Lexical analysis with error collection.
        // ----------------------------------------------------

        var tokens: [100]lexer.Token = undefined;
        var diagnostics: [100]lexer.Diagnostic = undefined;

        const diagnostic_count =
            lexer.tokenizeCollectErrors(
                sentence,
                &tokens,
                &diagnostics,
            );

        // ----------------------------------------------------
        // If lexical errors exist, display them all.
        // ----------------------------------------------------

        if (diagnostic_count > 0) {
            sortDiagnostics(
                diagnostics[0..diagnostic_count],
            );

            try displayLexicalErrors(
                stdout,
                sentence,
                diagnostics[0..diagnostic_count],
            );

            try stdout.flush();

            try pauseBeforeNextRun(
                stdin,
                stdout,
            );

            try clearTerminal(stdout);

            continue;
        }

        // ----------------------------------------------------
        // Syntax analysis.
        // ----------------------------------------------------

        const token_count =
            lexer.tokenize(
                sentence,
                &tokens,
            ) catch |err| {
                try stdout.print(
                    "\nUnexpected lexical error: {s}\n\n",
                    .{@errorName(err)},
                );

                try stdout.flush();

                try pauseBeforeNextRun(
                    stdin,
                    stdout,
                );

                try clearTerminal(stdout);

                continue;
            };

        var graph_parser = parser.Parser.init(
            tokens[0..token_count],
        );

        graph_parser.parseGraph() catch |err| {
            try displaySyntaxError(
                stdout,
                sentence,
                err,
            );

            try stdout.flush();

            try pauseBeforeNextRun(
                stdin,
                stdout,
            );

            try clearTerminal(stdout);

            continue;
        };

        // ----------------------------------------------------
        // LEFTMOST DERIVATION
        // ----------------------------------------------------

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

            try pauseBeforeNextRun(
                stdin,
                stdout,
            );

            try clearTerminal(stdout);

            continue;
        };

        try stdout.writeAll(
            "----------------------------------------\n",
        );

        try stdout.flush();

        // ----------------------------------------------------
        // Ask whether the user wants to see the parse tree.
        // ----------------------------------------------------

        const show_tree =
            try askYesNo(
                stdin,
                stdout,
                "\nDisplay parse tree? (yes/no): ",
            );

        // ----------------------------------------------------
        // PARSE TREE
        // ----------------------------------------------------

        if (show_tree) {
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

                try pauseBeforeNextRun(
                    stdin,
                    stdout,
                );

                try clearTerminal(stdout);

                continue;
            };

            try stdout.writeAll(
                "----------------------------------------\n",
            );

            try stdout.flush();
        }

        // ----------------------------------------------------
        // Ask whether the user wants graphical output.
        // ----------------------------------------------------

        const show_graph =
            try askYesNo(
                stdin,
                stdout,
                "\nDisplay graphical output? (yes/no): ",
            );

        // ----------------------------------------------------
        // Build actual Graph representation.
        // ----------------------------------------------------

        var plots: [100]plot.Plot = undefined;

        var graphics_parser = parser.Parser.init(
            tokens[0..token_count],
        );

        const graph =
            graphics_parser.parseGraphInto(
                &plots,
            ) catch |err| {
                try stdout.print(
                    "\nGRAPH DATA ERROR: {s}\n\n",
                    .{@errorName(err)},
                );

                try stdout.flush();

                try pauseBeforeNextRun(
                    stdin,
                    stdout,
                );

                try clearTerminal(stdout);

                continue;
            };

        // ----------------------------------------------------
        // RAYLIB GRAPHICAL OUTPUT
        // ----------------------------------------------------
        //
        // When graphical output is requested, Raylib opens
        // its own window.
        //
        // Closing the Raylib window acts as the user's
        // "continue" action.
        //
        // There is intentionally NO additional Enter pause
        // after the Raylib window closes.
        // ----------------------------------------------------

        if (show_graph) {
            try stdout.writeAll(
                "\nGRAPHICAL OUTPUT\n",
            );

            try stdout.writeAll(
                "----------------------------------------\n",
            );

            try stdout.writeAll(
                "Close the graphics window to continue.\n\n",
            );

            try stdout.flush();

            graphics.displayGraph(graph);

            // ------------------------------------------------
            // Raylib window has now been closed.
            // ------------------------------------------------

            try stdout.writeAll(
                "\nInput accepted.\n",
            );

            try stdout.flush();

            // ------------------------------------------------
            // Closing the Raylib window replaces the normal
            // Enter pause.
            //
            // Clear the terminal and begin the next run.
            // ------------------------------------------------

            try clearTerminal(stdout);

            continue;
        }

        // ----------------------------------------------------
        // Successful input when graphical output was not
        // requested.
        // ----------------------------------------------------

        try stdout.writeAll(
            "\nInput accepted.\n",
        );

        try stdout.flush();

        // ----------------------------------------------------
        // If there was no graphical window, use the normal
        // Enter pause before starting the next run.
        // ----------------------------------------------------

        try pauseBeforeNextRun(
            stdin,
            stdout,
        );

        try clearTerminal(stdout);
    }
}

// ============================================================
// Pause Before Next Run
// ============================================================

fn pauseBeforeNextRun(
    stdin: *std.Io.Reader,
    stdout: *std.Io.Writer,
) !void {
    try stdout.writeAll(
        "\nPress Enter to continue...",
    );

    try stdout.flush();

    _ = try stdin.takeByte();
}

// ============================================================
// Clear Terminal
// ============================================================

fn clearTerminal(
    writer: *std.Io.Writer,
) !void {
    try writer.writeAll(
        "\x1b[H\x1b[2J\x1b[3J\x1b[H",
    );

    try writer.flush();
}

// ============================================================
// Ask Yes/No
// ============================================================
//
// Accepts:
//   yes
//   y
//   no
//   n
//
// Matching is case-insensitive.
//

fn askYesNo(
    stdin: *std.Io.Reader,
    stdout: *std.Io.Writer,
    prompt: []const u8,
) !bool {
    while (true) {
        try stdout.writeAll(prompt);
        try stdout.flush();

        const answer =
            try stdin.takeDelimiter('\n') orelse return false;

        const trimmed = std.mem.trim(
            u8,
            answer,
            " \r\t",
        );

        if (std.ascii.eqlIgnoreCase(
            trimmed,
            "yes",
        ) or std.ascii.eqlIgnoreCase(
            trimmed,
            "y",
        )) {
            return true;
        }

        if (std.ascii.eqlIgnoreCase(
            trimmed,
            "no",
        ) or std.ascii.eqlIgnoreCase(
            trimmed,
            "n",
        )) {
            return false;
        }

        try stdout.writeAll(
            "Please enter yes/no or y/n.\n",
        );
    }
}

// ============================================================
// Check for incorrectly capitalized STOP
// ============================================================

fn isStopCommandWithWrongCase(
    input: []const u8,
) bool {
    if (input.len != 4) {
        return false;
    }

    const first = std.ascii.toLower(input[0]);
    const second = std.ascii.toLower(input[1]);
    const third = std.ascii.toLower(input[2]);
    const fourth = std.ascii.toLower(input[3]);

    return first == 's' and
        second == 't' and
        third == 'o' and
        fourth == 'p';
}

// ============================================================
// Display incorrect STOP capitalization
// ============================================================

fn displayStopCaseError(
    writer: *std.Io.Writer,
    input: []const u8,
) !void {
    try writer.writeAll(
        "\nINPUT INVALID\n\n",
    );

    try writer.writeAll(input);
    try writer.writeAll("\n");

    var i: usize = 0;

    while (i < input.len) : (i += 1) {
        try writer.writeAll("^");
    }

    try writer.writeAll("\n\n");

    try writer.writeAll(
        "Error 1:\n",
    );

    try writer.print(
        "Invalid termination command \"{s}\".\n",
        .{input},
    );

    try writer.writeAll(
        "The program can only be terminated by entering STOP in uppercase.\n\n",
    );
}

// ============================================================
// Diagnostic sorting
// ============================================================

fn sortDiagnostics(
    diagnostics: []lexer.Diagnostic,
) void {
    if (diagnostics.len < 2) {
        return;
    }

    var i: usize = 1;

    while (i < diagnostics.len) : (i += 1) {
        var j = i;

        while (j > 0 and
            diagnostics[j].start <
                diagnostics[j - 1].start)
        {
            const temporary = diagnostics[j];

            diagnostics[j] = diagnostics[j - 1];
            diagnostics[j - 1] = temporary;

            j -= 1;
        }
    }
}

// ============================================================
// Display lexical errors
// ============================================================

fn displayLexicalErrors(
    writer: *std.Io.Writer,
    input: []const u8,
    diagnostics: []const lexer.Diagnostic,
) !void {
    try writer.writeAll(
        "\nINPUT INVALID\n\n",
    );

    try writer.writeAll(input);
    try writer.writeAll("\n");

    var marker_end: usize = 0;

    for (diagnostics) |diagnostic| {
        if (diagnostic.end > marker_end) {
            marker_end = diagnostic.end;
        }
    }

    try writer.writeAll(" ");

    var marker_index: usize = 0;

    while (marker_index < marker_end and
        marker_index < input.len) : (marker_index += 1)
    {
        var marked = false;

        for (diagnostics) |diagnostic| {
            if (marker_index >= diagnostic.start and
                marker_index < diagnostic.end)
            {
                marked = true;
                break;
            }
        }

        if (marked) {
            try writer.writeAll("^");
        } else {
            try writer.writeAll(" ");
        }
    }

    try writer.writeAll("\n\n");

    for (diagnostics, 0..) |diagnostic, index| {
        try writer.print(
            "Error {d}:\n",
            .{index + 1},
        );

        try displayDiagnosticMessage(
            writer,
            input,
            diagnostic,
        );

        try writer.writeAll("\n");
    }
}

// ============================================================
// Diagnostic messages
// ============================================================

fn displayDiagnosticMessage(
    writer: *std.Io.Writer,
    input: []const u8,
    diagnostic: lexer.Diagnostic,
) !void {
    switch (diagnostic.kind) {
        .invalid_word => {
            try writer.print(
                "Unknown word \"{s}\".\n",
                .{
                    input[diagnostic.start..diagnostic.end],
                },
            );

            try writer.writeAll(
                "Expected one of: start, end, bar, line, grid, or fill.\n",
            );
        },

        .invalid_character => {
            try writer.print(
                "Invalid character '{c}'.\n",
                .{
                    input[diagnostic.start],
                },
            );
        },

        .invalid_coordinate => {
            try writer.print(
                "Invalid coordinate \"{s}\".\n",
                .{
                    input[diagnostic.start..diagnostic.end],
                },
            );

            try writer.writeAll(
                "Coordinates must contain one letter from a to j followed by exactly one digit from 0 to 9.\n",
            );
        },

        .space_inside_coordinate => {
            try writer.writeAll(
                "Spaces are not allowed inside a coordinate.\n",
            );

            try writer.writeAll(
                "A coordinate must look like a1, b2, or j9.\n",
            );
        },

        .space_before_comma => {
            try writer.writeAll(
                "Spaces are not allowed before a comma.\n",
            );
        },

        .space_after_comma => {
            try writer.writeAll(
                "Spaces are not allowed after a comma.\n",
            );
        },

        .too_many_tokens => {
            try writer.writeAll(
                "The input contains too many tokens.\n",
            );

            try writer.writeAll(
                "Please shorten the input and try again.\n",
            );
        },
    }
}

// ============================================================
// Syntax error display
// ============================================================

fn displaySyntaxError(
    writer: *std.Io.Writer,
    input: []const u8,
    err: anyerror,
) !void {
    try writer.writeAll(
        "\nINPUT INVALID\n\n",
    );

    try writer.writeAll(input);
    try writer.writeAll("\n\n");

    try writer.writeAll(
        "Error 1:\n",
    );

    switch (err) {
        error.UnexpectedEndOfInput => {
            try writer.writeAll(
                "The input ended before the graph was complete.\n",
            );
        },

        error.ExpectedStart => {
            try writer.writeAll(
                "The graph must begin with the keyword \"start\".\n",
            );
        },

        error.ExpectedEnd => {
            try writer.writeAll(
                "The graph must end with the keyword \"end\".\n",
            );
        },

        error.ExpectedPlot => {
            try writer.writeAll(
                "A plot command was expected.\n",
            );

            try writer.writeAll(
                "Expected: bar, line, grid, or fill.\n",
            );
        },

        error.ExpectedCoordinate => {
            try writer.writeAll(
                "A coordinate was expected.\n",
            );

            try writer.writeAll(
                "Coordinates must contain a letter from a to j followed by one digit from 0 to 9.\n",
            );
        },

        error.ExpectedComma => {
            try writer.writeAll(
                "A comma was expected between the required values.\n",
            );
        },

        error.ExpectedNumber => {
            try writer.writeAll(
                "A number from 0 to 9 was expected.\n",
            );
        },

        error.TooManyPlots => {
            try writer.writeAll(
                "The graph contains too many plot commands.\n",
            );
        },

        error.UnexpectedToken => {
            try writer.writeAll(
                "The input contains a token that is not valid in this part of the graph.\n",
            );
        },

        else => {
            try writer.writeAll(
                "The graph does not follow the required grammar.\n",
            );
        },
    }

    try writer.writeAll("\n");
}
