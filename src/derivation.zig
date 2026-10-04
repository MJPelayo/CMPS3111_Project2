const std = @import("std");
const lexer = @import("lexer.zig");
const parser = @import("parser.zig");
const plot = @import("plot.zig");

pub const DerivationError = error{
    InvalidCoordinate,
    InvalidNumber,
    InvalidInput,
    TooManyPlots,
};

// ============================================================
// Display a true LEFTMOST derivation for a complete graph.
//
// Grammar:
//
// <graph> → start <plot_stmts> end
//
// <plot_stmts> → <plot>
//              | <plot> ; <plot_stmts>
//
// <plot> → bar <x><y>,<y>
//        | line <x><y>,<x><y>
//        | grid <x><y>
//        | fill <x><y>
// ============================================================

pub fn displayGraphDerivation(
    writer: *std.Io.Writer,
    tokens: []const lexer.Token,
) !void {
    var plots: [100]plot.Plot = undefined;

    var graph_parser = parser.Parser.init(tokens);

    const graph = graph_parser.parseGraphInto(&plots) catch |err| {
        return switch (err) {
            error.TooManyPlots => error.TooManyPlots,
            else => error.InvalidInput,
        };
    };

    if (graph.plots.len == 0) {
        return error.InvalidInput;
    }

    // --------------------------------------------------------
    // <graph>
    // --------------------------------------------------------

    try printStep(
        writer,
        "<graph>",
    );

    // --------------------------------------------------------
    // <graph> → start <plot_stmts> end
    // --------------------------------------------------------

    try printStep(
        writer,
        "start <plot_stmts> end",
    );

    // --------------------------------------------------------
    // Expand <plot_stmts>.
    //
    // Multiple plots:
    //
    // <plot_stmts> → <plot> ; <plot_stmts>
    //
    // One plot:
    //
    // <plot_stmts> → <plot>
    // --------------------------------------------------------

    if (graph.plots.len > 1) {
        try printStep(
            writer,
            "start <plot> ; <plot_stmts> end",
        );
    } else {
        try printStep(
            writer,
            "start <plot> end",
        );
    }

    // --------------------------------------------------------
    // Keep the already-derived plots.
    //
    // Example:
    //
    // bar a1,5
    //
    // Then the next sentential form begins:
    //
    // start bar a1,5 ; ...
    // --------------------------------------------------------

    var completed: [4096]u8 = undefined;
    var completed_length: usize = 0;

    for (graph.plots, 0..) |current_plot, index| {
        const has_remaining =
            index + 1 < graph.plots.len;

        // ----------------------------------------------------
        // For every plot after the first one, the current
        // leftmost nonterminal is <plot_stmts>.
        //
        // Expand it first.
        // ----------------------------------------------------

        if (index > 0) {
            var step_buffer: [4096]u8 = undefined;

            if (has_remaining) {
                const step = try std.fmt.bufPrint(
                    &step_buffer,
                    "start {s} ; <plot> ; <plot_stmts> end",
                    .{
                        completed[0..completed_length],
                    },
                );

                try printStep(
                    writer,
                    step,
                );
            } else {
                const step = try std.fmt.bufPrint(
                    &step_buffer,
                    "start {s} ; <plot> end",
                    .{
                        completed[0..completed_length],
                    },
                );

                try printStep(
                    writer,
                    step,
                );
            }
        }

        // ----------------------------------------------------
        // Now expand the new leftmost <plot>.
        // ----------------------------------------------------

        try displayPlotExpansion(
            writer,
            current_plot,
            completed[0..completed_length],
            has_remaining,
        );

        // ----------------------------------------------------
        // Add this completed plot to the prefix.
        // ----------------------------------------------------

        completed_length = try appendCompletedPlot(
            &completed,
            completed_length,
            current_plot,
        );
    }
}

// ============================================================
// Expand one <plot> in the current sentential form.
// ============================================================

fn displayPlotExpansion(
    writer: *std.Io.Writer,
    current: plot.Plot,
    completed: []const u8,
    has_remaining: bool,
) !void {
    var buffer: [4096]u8 = undefined;

    // --------------------------------------------------------
    // Build the prefix.
    //
    // When there are already completed plots, the grammar
    // requires:
    //
    // start <completed> ; <current plot> ...
    //
    // The semicolon belongs between the completed portion
    // and the current plot.
    // --------------------------------------------------------

    var prefix_buffer: [4096]u8 = undefined;

    const prefix = if (completed.len == 0)
        try std.fmt.bufPrint(
            &prefix_buffer,
            "start ",
            .{},
        )
    else
        try std.fmt.bufPrint(
            &prefix_buffer,
            "start {s} ; ",
            .{completed},
        );

    // The suffix represents everything that remains after the
    // current <plot>.
    const suffix =
        if (has_remaining)
            " ; <plot_stmts> end"
        else
            " end";

    // --------------------------------------------------------
    // BAR
    //
    // <plot> → bar <x><y>,<y>
    // --------------------------------------------------------

    if (current.kind == .bar) {
        const coordinate = current.first_coordinate;

        const width =
            current.number orelse
            return error.InvalidNumber;

        var step = try std.fmt.bufPrint(
            &buffer,
            "{s}bar <x><y>,<y>{s}",
            .{
                prefix,
                suffix,
            },
        );

        try printStep(writer, step);

        // Expand <x>.
        step = try std.fmt.bufPrint(
            &buffer,
            "{s}bar {c}<y>,<y>{s}",
            .{
                prefix,
                coordinate[0],
                suffix,
            },
        );

        try printStep(writer, step);

        // Expand first <y>.
        step = try std.fmt.bufPrint(
            &buffer,
            "{s}bar {c}{c},<y>{s}",
            .{
                prefix,
                coordinate[0],
                coordinate[1],
                suffix,
            },
        );

        try printStep(writer, step);

        // Expand second <y>.
        step = try std.fmt.bufPrint(
            &buffer,
            "{s}bar {c}{c},{d}{s}",
            .{
                prefix,
                coordinate[0],
                coordinate[1],
                width,
                suffix,
            },
        );

        try printStep(writer, step);

        return;
    }

    // --------------------------------------------------------
    // LINE
    //
    // <plot> → line <x><y>,<x><y>
    // --------------------------------------------------------

    if (current.kind == .line) {
        const first = current.first_coordinate;

        const second =
            current.second_coordinate orelse
            return error.InvalidCoordinate;

        var step = try std.fmt.bufPrint(
            &buffer,
            "{s}line <x><y>,<x><y>{s}",
            .{
                prefix,
                suffix,
            },
        );

        try printStep(writer, step);

        // Expand first <x>.
        step = try std.fmt.bufPrint(
            &buffer,
            "{s}line {c}<y>,<x><y>{s}",
            .{
                prefix,
                first[0],
                suffix,
            },
        );

        try printStep(writer, step);

        // Expand first <y>.
        step = try std.fmt.bufPrint(
            &buffer,
            "{s}line {c}{c},<x><y>{s}",
            .{
                prefix,
                first[0],
                first[1],
                suffix,
            },
        );

        try printStep(writer, step);

        // Expand second <x>.
        step = try std.fmt.bufPrint(
            &buffer,
            "{s}line {c}{c},{c}<y>{s}",
            .{
                prefix,
                first[0],
                first[1],
                second[0],
                suffix,
            },
        );

        try printStep(writer, step);

        // Expand second <y>.
        step = try std.fmt.bufPrint(
            &buffer,
            "{s}line {c}{c},{c}{c}{s}",
            .{
                prefix,
                first[0],
                first[1],
                second[0],
                second[1],
                suffix,
            },
        );

        try printStep(writer, step);

        return;
    }

    // --------------------------------------------------------
    // GRID
    //
    // <plot> → grid <x><y>
    // --------------------------------------------------------

    if (current.kind == .grid) {
        const coordinate = current.first_coordinate;

        var step = try std.fmt.bufPrint(
            &buffer,
            "{s}grid <x><y>{s}",
            .{
                prefix,
                suffix,
            },
        );

        try printStep(writer, step);

        // Expand <x>.
        step = try std.fmt.bufPrint(
            &buffer,
            "{s}grid {c}<y>{s}",
            .{
                prefix,
                coordinate[0],
                suffix,
            },
        );

        try printStep(writer, step);

        // Expand <y>.
        step = try std.fmt.bufPrint(
            &buffer,
            "{s}grid {c}{c}{s}",
            .{
                prefix,
                coordinate[0],
                coordinate[1],
                suffix,
            },
        );

        try printStep(writer, step);

        return;
    }

    // --------------------------------------------------------
    // FILL
    //
    // <plot> → fill <x><y>
    // --------------------------------------------------------

    if (current.kind == .fill) {
        const coordinate = current.first_coordinate;

        var step = try std.fmt.bufPrint(
            &buffer,
            "{s}fill <x><y>{s}",
            .{
                prefix,
                suffix,
            },
        );

        try printStep(writer, step);

        // Expand <x>.
        step = try std.fmt.bufPrint(
            &buffer,
            "{s}fill {c}<y>{s}",
            .{
                prefix,
                coordinate[0],
                suffix,
            },
        );

        try printStep(writer, step);

        // Expand <y>.
        step = try std.fmt.bufPrint(
            &buffer,
            "{s}fill {c}{c}{s}",
            .{
                prefix,
                coordinate[0],
                coordinate[1],
                suffix,
            },
        );

        try printStep(writer, step);

        return;
    }

    return error.InvalidInput;
}

// ============================================================
// Add a completed plot to the prefix.
// ============================================================

fn appendCompletedPlot(
    buffer: []u8,
    current_length: usize,
    current: plot.Plot,
) !usize {
    var text_buffer: [256]u8 = undefined;

    const text = switch (current.kind) {
        .bar => blk: {
            const width =
                current.number orelse
                return error.InvalidNumber;

            break :blk try std.fmt.bufPrint(
                &text_buffer,
                "bar {c}{c},{d}",
                .{
                    current.first_coordinate[0],
                    current.first_coordinate[1],
                    width,
                },
            );
        },

        .line => blk: {
            const second =
                current.second_coordinate orelse
                return error.InvalidCoordinate;

            break :blk try std.fmt.bufPrint(
                &text_buffer,
                "line {c}{c},{c}{c}",
                .{
                    current.first_coordinate[0],
                    current.first_coordinate[1],
                    second[0],
                    second[1],
                },
            );
        },

        .grid => try std.fmt.bufPrint(
            &text_buffer,
            "grid {c}{c}",
            .{
                current.first_coordinate[0],
                current.first_coordinate[1],
            },
        ),

        .fill => try std.fmt.bufPrint(
            &text_buffer,
            "fill {c}{c}",
            .{
                current.first_coordinate[0],
                current.first_coordinate[1],
            },
        ),
    };

    var next_length = current_length;

    // Add the semicolon between completed plots.
    if (next_length > 0) {
        if (next_length + 3 > buffer.len) {
            return error.InvalidInput;
        }

        buffer[next_length] = ' ';
        buffer[next_length + 1] = ';';
        buffer[next_length + 2] = ' ';

        next_length += 3;
    }

    if (next_length + text.len > buffer.len) {
        return error.InvalidInput;
    }

    std.mem.copyForwards(
        u8,
        buffer[next_length .. next_length + text.len],
        text,
    );

    return next_length + text.len;
}

// ============================================================
// Coordinate validation.
// ============================================================

fn validateCoordinate(
    coordinate: []const u8,
) DerivationError!void {
    if (coordinate.len != 2) {
        return error.InvalidCoordinate;
    }

    const x = coordinate[0];
    const y = coordinate[1];

    if (x < 'a' or x > 'j') {
        return error.InvalidCoordinate;
    }

    if (y < '0' or y > '9') {
        return error.InvalidCoordinate;
    }
}

// ============================================================
// Print one derivation step.
// ============================================================

fn printStep(
    writer: *std.Io.Writer,
    text: []const u8,
) !void {
    try writer.print(
        "⇒ {s}\n",
        .{text},
    );
}

// ============================================================
// Individual BAR derivation.
// ============================================================

pub fn displayBarDerivation(
    writer: *std.Io.Writer,
    coordinate: []const u8,
    width: u8,
) !void {
    try validateCoordinate(coordinate);

    if (width > 9) {
        return error.InvalidNumber;
    }

    const x = coordinate[0];
    const y = coordinate[1];

    try printStep(writer, "<graph>");
    try printStep(writer, "start <plot_stmts> end");
    try printStep(writer, "start <plot> end");
    try printStep(writer, "start bar <x><y>,<y> end");

    var buffer: [256]u8 = undefined;

    const step_x = try std.fmt.bufPrint(
        &buffer,
        "start bar {c}<y>,<y> end",
        .{x},
    );

    try printStep(writer, step_x);

    const step_y = try std.fmt.bufPrint(
        &buffer,
        "start bar {c}{c},<y> end",
        .{
            x,
            y,
        },
    );

    try printStep(writer, step_y);

    const final_step = try std.fmt.bufPrint(
        &buffer,
        "start bar {c}{c},{d} end",
        .{
            x,
            y,
            width,
        },
    );

    try printStep(writer, final_step);
}

// ============================================================
// Individual LINE derivation.
// ============================================================

pub fn displayLineDerivation(
    writer: *std.Io.Writer,
    first_coordinate: []const u8,
    second_coordinate: []const u8,
) !void {
    try validateCoordinate(first_coordinate);
    try validateCoordinate(second_coordinate);

    const first_x = first_coordinate[0];
    const first_y = first_coordinate[1];

    const second_x = second_coordinate[0];
    const second_y = second_coordinate[1];

    try printStep(writer, "<graph>");
    try printStep(writer, "start <plot_stmts> end");
    try printStep(writer, "start <plot> end");
    try printStep(
        writer,
        "start line <x><y>,<x><y> end",
    );

    var buffer: [256]u8 = undefined;

    const step_first_x = try std.fmt.bufPrint(
        &buffer,
        "start line {c}<y>,<x><y> end",
        .{first_x},
    );

    try printStep(writer, step_first_x);

    const step_first_y = try std.fmt.bufPrint(
        &buffer,
        "start line {c}{c},<x><y> end",
        .{
            first_x,
            first_y,
        },
    );

    try printStep(writer, step_first_y);

    const step_second_x = try std.fmt.bufPrint(
        &buffer,
        "start line {c}{c},{c}<y> end",
        .{
            first_x,
            first_y,
            second_x,
        },
    );

    try printStep(writer, step_second_x);

    const final_step = try std.fmt.bufPrint(
        &buffer,
        "start line {c}{c},{c}{c} end",
        .{
            first_x,
            first_y,
            second_x,
            second_y,
        },
    );

    try printStep(writer, final_step);
}

// ============================================================
// Individual GRID derivation.
// ============================================================

pub fn displayGridDerivation(
    writer: *std.Io.Writer,
    coordinate: []const u8,
) !void {
    try validateCoordinate(coordinate);

    const x = coordinate[0];
    const y = coordinate[1];

    try printStep(writer, "<graph>");
    try printStep(writer, "start <plot_stmts> end");
    try printStep(writer, "start <plot> end");
    try printStep(
        writer,
        "start grid <x><y> end",
    );

    var buffer: [256]u8 = undefined;

    const step_x = try std.fmt.bufPrint(
        &buffer,
        "start grid {c}<y> end",
        .{x},
    );

    try printStep(writer, step_x);

    const final_step = try std.fmt.bufPrint(
        &buffer,
        "start grid {c}{c} end",
        .{
            x,
            y,
        },
    );

    try printStep(writer, final_step);
}

// ============================================================
// Individual FILL derivation.
// ============================================================

pub fn displayFillDerivation(
    writer: *std.Io.Writer,
    coordinate: []const u8,
) !void {
    try validateCoordinate(coordinate);

    const x = coordinate[0];
    const y = coordinate[1];

    try printStep(writer, "<graph>");
    try printStep(writer, "start <plot_stmts> end");
    try printStep(writer, "start <plot> end");
    try printStep(
        writer,
        "start fill <x><y> end",
    );

    var buffer: [256]u8 = undefined;

    const step_x = try std.fmt.bufPrint(
        &buffer,
        "start fill {c}<y> end",
        .{x},
    );

    try printStep(writer, step_x);

    const final_step = try std.fmt.bufPrint(
        &buffer,
        "start fill {c}{c} end",
        .{
            x,
            y,
        },
    );

    try printStep(writer, final_step);
}

// ============================================================
// Tests
// ============================================================

test "display bar derivation" {
    var output_buffer: [4096]u8 = undefined;

    var writer = std.Io.Writer.fixed(
        &output_buffer,
    );

    try displayBarDerivation(
        &writer,
        "a1",
        5,
    );

    const output = output_buffer[0..writer.end];

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "<graph>",
        ) != null,
    );

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "start <plot_stmts> end",
        ) != null,
    );

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "start bar <x><y>,<y> end",
        ) != null,
    );

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "start bar a1,5 end",
        ) != null,
    );
}

test "display line derivation" {
    var output_buffer: [4096]u8 = undefined;

    var writer = std.Io.Writer.fixed(
        &output_buffer,
    );

    try displayLineDerivation(
        &writer,
        "a1",
        "b2",
    );

    const output = output_buffer[0..writer.end];

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "start line <x><y>,<x><y> end",
        ) != null,
    );

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "start line a1,b2 end",
        ) != null,
    );
}

test "display grid derivation" {
    var output_buffer: [4096]u8 = undefined;

    var writer = std.Io.Writer.fixed(
        &output_buffer,
    );

    try displayGridDerivation(
        &writer,
        "c4",
    );

    const output = output_buffer[0..writer.end];

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "start grid <x><y> end",
        ) != null,
    );

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "start grid c4 end",
        ) != null,
    );
}

test "display fill derivation" {
    var output_buffer: [4096]u8 = undefined;

    var writer = std.Io.Writer.fixed(
        &output_buffer,
    );

    try displayFillDerivation(
        &writer,
        "e5",
    );

    const output = output_buffer[0..writer.end];

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "start fill <x><y> end",
        ) != null,
    );

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "start fill e5 end",
        ) != null,
    );
}

test "reject invalid bar coordinate" {
    var output_buffer: [4096]u8 = undefined;

    var writer = std.Io.Writer.fixed(
        &output_buffer,
    );

    try std.testing.expectError(
        error.InvalidCoordinate,
        displayBarDerivation(
            &writer,
            "z5",
            5,
        ),
    );
}

test "reject invalid line coordinate" {
    var output_buffer: [4096]u8 = undefined;

    var writer = std.Io.Writer.fixed(
        &output_buffer,
    );

    try std.testing.expectError(
        error.InvalidCoordinate,
        displayLineDerivation(
            &writer,
            "a1",
            "z5",
        ),
    );
}

test "reject invalid grid coordinate" {
    var output_buffer: [4096]u8 = undefined;

    var writer = std.Io.Writer.fixed(
        &output_buffer,
    );

    try std.testing.expectError(
        error.InvalidCoordinate,
        displayGridDerivation(
            &writer,
            "a",
        ),
    );
}

test "reject invalid fill coordinate" {
    var output_buffer: [4096]u8 = undefined;

    var writer = std.Io.Writer.fixed(
        &output_buffer,
    );

    try std.testing.expectError(
        error.InvalidCoordinate,
        displayFillDerivation(
            &writer,
            "k2",
        ),
    );
}

test "reject invalid bar number" {
    var output_buffer: [4096]u8 = undefined;

    var writer = std.Io.Writer.fixed(
        &output_buffer,
    );

    try std.testing.expectError(
        error.InvalidNumber,
        displayBarDerivation(
            &writer,
            "a1",
            10,
        ),
    );
}

test "display graph derivation for two plots" {
    const input =
        "start bar a1,5;grid c4 end";

    var tokens: [30]lexer.Token = undefined;

    const token_count = try lexer.tokenize(
        input,
        &tokens,
    );

    var output_buffer: [4096]u8 = undefined;

    var writer = std.Io.Writer.fixed(
        &output_buffer,
    );

    try displayGraphDerivation(
        &writer,
        tokens[0..token_count],
    );

    const output = output_buffer[0..writer.end];

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "start <plot> ; <plot_stmts> end",
        ) != null,
    );

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "start bar <x><y>,<y> ; <plot_stmts> end",
        ) != null,
    );

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "start bar a1,5 ; <plot_stmts> end",
        ) != null,
    );

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "start bar a1,5 ; <plot> end",
        ) != null,
    );

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "start bar a1,5 ; grid <x><y> end",
        ) != null,
    );

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "start bar a1,5 ; grid c4 end",
        ) != null,
    );
}

test "display graph derivation for mixed plots" {
    const input =
        "start line b2,c3;fill e5;bar f6,2 end";

    var tokens: [40]lexer.Token = undefined;

    const token_count = try lexer.tokenize(
        input,
        &tokens,
    );

    var output_buffer: [4096]u8 = undefined;

    var writer = std.Io.Writer.fixed(
        &output_buffer,
    );

    try displayGraphDerivation(
        &writer,
        tokens[0..token_count],
    );

    const output = output_buffer[0..writer.end];

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "start line b2,c3 ; <plot_stmts> end",
        ) != null,
    );

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "start line b2,c3 ; fill <x><y> ; <plot_stmts> end",
        ) != null,
    );

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "start line b2,c3 ; fill e5 ; <plot_stmts> end",
        ) != null,
    );

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "start line b2,c3 ; fill e5 ; bar <x><y>,<y> end",
        ) != null,
    );

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "start line b2,c3 ; fill e5 ; bar f6,2 end",
        ) != null,
    );
}
