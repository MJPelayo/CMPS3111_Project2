const std = @import("std");
const lexer = @import("lexer.zig");

pub const DerivationError = error{
    InvalidCoordinate,
    InvalidNumber,
    InvalidInput,
};

// ============================================================
// Display the leftmost derivation for a complete graph.
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
    if (tokens.len < 3) {
        return error.InvalidInput;
    }

    // The first derivation step is always <graph>.
    try printStep(writer, "<graph>");

    // Expand <graph>.
    try printStep(
        writer,
        "start <plot_stmts> end",
    );

    // We now derive the complete plot statement list.
    try displayPlotStatements(
        writer,
        tokens,
    );
}

// ============================================================
// Derive the complete <plot_stmts> sequence.
//
// This function works from the token list and determines how
// many plots are present.
//
// For multiple plots:
//
// <plot_stmts>
// ⇒ <plot> ; <plot_stmts>
//
// For the final plot:
//
// <plot_stmts>
// ⇒ <plot>
// ============================================================

fn displayPlotStatements(
    writer: *std.Io.Writer,
    tokens: []const lexer.Token,
) !void {
    var position: usize = 1;

    while (position < tokens.len) {
        if (tokens[position].kind == .end) {
            break;
        }

        // Find the end of the current plot.
        const plot_end = findPlotEnd(
            tokens,
            position,
        );

        if (plot_end <= position) {
            return error.InvalidInput;
        }

        // Determine whether another plot follows.
        const has_more_plots =
            plot_end < tokens.len and
            tokens[plot_end].kind == .semicolon;

        if (has_more_plots) {
            try displayPlotWithRemainingStatements(
                writer,
                tokens[position..plot_end],
                true,
            );

            try printStep(
                writer,
                "start <previous_plot> ; <plot_stmts> end",
            );

            position = plot_end + 1;
        } else {
            try displayPlotWithRemainingStatements(
                writer,
                tokens[position..plot_end],
                false,
            );

            position = plot_end;
        }
    }
}

// ============================================================
// Find where one plot ends.
//
// A plot ends at either:
//   - a semicolon
//   - the end token
// ============================================================

fn findPlotEnd(
    tokens: []const lexer.Token,
    start_position: usize,
) usize {
    var position = start_position;

    while (position < tokens.len) {
        if (tokens[position].kind == .semicolon or
            tokens[position].kind == .end)
        {
            break;
        }

        position += 1;
    }

    return position;
}

// ============================================================
// Display the derivation for one plot.
//
// This function expands the leftmost plot completely.
//
// The surrounding <plot_stmts> is represented by the caller.
// ============================================================

fn displayPlotWithRemainingStatements(
    writer: *std.Io.Writer,
    plot_tokens: []const lexer.Token,
    has_more_plots: bool,
) !void {
    if (plot_tokens.len == 0) {
        return error.InvalidInput;
    }

    const plot_kind = plot_tokens[0].kind;

    switch (plot_kind) {
        .bar => {
            if (plot_tokens.len != 4) {
                return error.InvalidInput;
            }

            const coordinate =
                plot_tokens[1].lexeme;

            const width_text =
                plot_tokens[3].lexeme;

            if (width_text.len != 1) {
                return error.InvalidNumber;
            }

            const width =
                width_text[0] - '0';

            try displayPlotStart(
                writer,
                "bar",
                has_more_plots,
            );

            try displayBarExpansion(
                writer,
                coordinate,
                width,
                has_more_plots,
            );
        },

        .line => {
            if (plot_tokens.len != 4) {
                return error.InvalidInput;
            }

            const first_coordinate =
                plot_tokens[1].lexeme;

            const second_coordinate =
                plot_tokens[3].lexeme;

            try displayPlotStart(
                writer,
                "line",
                has_more_plots,
            );

            try displayLineExpansion(
                writer,
                first_coordinate,
                second_coordinate,
                has_more_plots,
            );
        },

        .grid => {
            if (plot_tokens.len != 2) {
                return error.InvalidInput;
            }

            const coordinate =
                plot_tokens[1].lexeme;

            try displayPlotStart(
                writer,
                "grid",
                has_more_plots,
            );

            try displaySimpleExpansion(
                writer,
                "grid",
                coordinate,
                has_more_plots,
            );
        },

        .fill => {
            if (plot_tokens.len != 2) {
                return error.InvalidInput;
            }

            const coordinate =
                plot_tokens[1].lexeme;

            try displayPlotStart(
                writer,
                "fill",
                has_more_plots,
            );

            try displaySimpleExpansion(
                writer,
                "fill",
                coordinate,
                has_more_plots,
            );
        },

        else => {
            return error.InvalidInput;
        },
    }
}

// ============================================================
// Display the beginning of a plot derivation.
// ============================================================

fn displayPlotStart(
    writer: *std.Io.Writer,
    plot_name: []const u8,
    has_more_plots: bool,
) !void {
    if (has_more_plots) {
        try writer.print(
            "⇒ start <plot> ; <plot_stmts> end\n",
            .{},
        );
    } else {
        try writer.print(
            "⇒ start <plot> end\n",
            .{},
        );
    }

    if (has_more_plots) {
        try writer.print(
            "⇒ start {s} <plot_tail> ; <plot_stmts> end\n",
            .{plot_name},
        );
    } else {
        try writer.print(
            "⇒ start {s} <plot_tail> end\n",
            .{plot_name},
        );
    }
}

// ============================================================
// BAR expansion.
// ============================================================

fn displayBarExpansion(
    writer: *std.Io.Writer,
    coordinate: []const u8,
    width: u8,
    has_more_plots: bool,
) !void {
    try validateCoordinate(coordinate);

    if (width > 9) {
        return error.InvalidNumber;
    }

    const x = coordinate[0];
    const y = coordinate[1];

    var buffer: [256]u8 = undefined;

    if (has_more_plots) {
        try printStep(
            writer,
            "start bar <x><y>,<y> ; <plot_stmts> end",
        );

        const step_x = try std.fmt.bufPrint(
            &buffer,
            "start bar {c}<y>,<y> ; <plot_stmts> end",
            .{x},
        );
        try printStep(writer, step_x);

        const step_y = try std.fmt.bufPrint(
            &buffer,
            "start bar {c}{c},<y> ; <plot_stmts> end",
            .{ x, y },
        );
        try printStep(writer, step_y);

        const final_step = try std.fmt.bufPrint(
            &buffer,
            "start bar {c}{c},{d} ; <plot_stmts> end",
            .{ x, y, width },
        );
        try printStep(writer, final_step);
    } else {
        try printStep(
            writer,
            "start bar <x><y>,<y> end",
        );

        const step_x = try std.fmt.bufPrint(
            &buffer,
            "start bar {c}<y>,<y> end",
            .{x},
        );
        try printStep(writer, step_x);

        const step_y = try std.fmt.bufPrint(
            &buffer,
            "start bar {c}{c},<y> end",
            .{ x, y },
        );
        try printStep(writer, step_y);

        const final_step = try std.fmt.bufPrint(
            &buffer,
            "start bar {c}{c},{d} end",
            .{ x, y, width },
        );
        try printStep(writer, final_step);
    }
}

// ============================================================
// LINE expansion.
// ============================================================

fn displayLineExpansion(
    writer: *std.Io.Writer,
    first_coordinate: []const u8,
    second_coordinate: []const u8,
    has_more_plots: bool,
) !void {
    try validateCoordinate(first_coordinate);
    try validateCoordinate(second_coordinate);

    const first_x = first_coordinate[0];
    const first_y = first_coordinate[1];

    const second_x = second_coordinate[0];
    const second_y = second_coordinate[1];

    var buffer: [256]u8 = undefined;

    const suffix =
        if (has_more_plots)
            " ; <plot_stmts> end"
        else
            " end";

    const step_1 = try std.fmt.bufPrint(
        &buffer,
        "start line <x><y>,<x><y>{s}",
        .{suffix},
    );
    try printStep(writer, step_1);

    const step_2 = try std.fmt.bufPrint(
        &buffer,
        "start line {c}<y>,<x><y>{s}",
        .{ first_x, suffix },
    );
    try printStep(writer, step_2);

    const step_3 = try std.fmt.bufPrint(
        &buffer,
        "start line {c}{c},<x><y>{s}",
        .{ first_x, first_y, suffix },
    );
    try printStep(writer, step_3);

    const step_4 = try std.fmt.bufPrint(
        &buffer,
        "start line {c}{c},{c}<y>{s}",
        .{
            first_x,
            first_y,
            second_x,
            suffix,
        },
    );
    try printStep(writer, step_4);

    const final_step = try std.fmt.bufPrint(
        &buffer,
        "start line {c}{c},{c}{c}{s}",
        .{
            first_x,
            first_y,
            second_x,
            second_y,
            suffix,
        },
    );
    try printStep(writer, final_step);
}

// ============================================================
// GRID / FILL expansion.
// ============================================================

fn displaySimpleExpansion(
    writer: *std.Io.Writer,
    plot_name: []const u8,
    coordinate: []const u8,
    has_more_plots: bool,
) !void {
    try validateCoordinate(coordinate);

    const x = coordinate[0];
    const y = coordinate[1];

    const suffix =
        if (has_more_plots)
            " ; <plot_stmts> end"
        else
            " end";

    var buffer: [256]u8 = undefined;

    const step_1 = try std.fmt.bufPrint(
        &buffer,
        "start {s} <x><y>{s}",
        .{ plot_name, suffix },
    );
    try printStep(writer, step_1);

    const step_2 = try std.fmt.bufPrint(
        &buffer,
        "start {s} {c}<y>{s}",
        .{ plot_name, x, suffix },
    );
    try printStep(writer, step_2);

    const final_step = try std.fmt.bufPrint(
        &buffer,
        "start {s} {c}{c}{s}",
        .{ plot_name, x, y, suffix },
    );
    try printStep(writer, final_step);
}

// ============================================================
// Existing individual BAR derivation.
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

    var step_buffer: [256]u8 = undefined;

    const step_x = try std.fmt.bufPrint(
        &step_buffer,
        "start bar {c}<y>,<y> end",
        .{x},
    );
    try printStep(writer, step_x);

    const step_y = try std.fmt.bufPrint(
        &step_buffer,
        "start bar {c}{c},<y> end",
        .{ x, y },
    );
    try printStep(writer, step_y);

    const final_step = try std.fmt.bufPrint(
        &step_buffer,
        "start bar {c}{c},{d} end",
        .{ x, y, width },
    );
    try printStep(writer, final_step);
}

// ============================================================
// Existing individual LINE derivation.
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
    try printStep(writer, "start line <x><y>,<x><y> end");

    var step_buffer: [256]u8 = undefined;

    const step_first_x = try std.fmt.bufPrint(
        &step_buffer,
        "start line {c}<y>,<x><y> end",
        .{first_x},
    );
    try printStep(writer, step_first_x);

    const step_first_y = try std.fmt.bufPrint(
        &step_buffer,
        "start line {c}{c},<x><y> end",
        .{ first_x, first_y },
    );
    try printStep(writer, step_first_y);

    const step_second_x = try std.fmt.bufPrint(
        &step_buffer,
        "start line {c}{c},{c}<y> end",
        .{
            first_x,
            first_y,
            second_x,
        },
    );
    try printStep(writer, step_second_x);

    const final_step = try std.fmt.bufPrint(
        &step_buffer,
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
// Existing individual GRID derivation.
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
    try printStep(writer, "start grid <x><y> end");

    var step_buffer: [256]u8 = undefined;

    const step_x = try std.fmt.bufPrint(
        &step_buffer,
        "start grid {c}<y> end",
        .{x},
    );
    try printStep(writer, step_x);

    const final_step = try std.fmt.bufPrint(
        &step_buffer,
        "start grid {c}{c} end",
        .{ x, y },
    );
    try printStep(writer, final_step);
}

// ============================================================
// Existing individual FILL derivation.
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
    try printStep(writer, "start fill <x><y> end");

    var step_buffer: [256]u8 = undefined;

    const step_x = try std.fmt.bufPrint(
        &step_buffer,
        "start fill {c}<y> end",
        .{x},
    );
    try printStep(writer, step_x);

    const final_step = try std.fmt.bufPrint(
        &step_buffer,
        "start fill {c}{c} end",
        .{ x, y },
    );
    try printStep(writer, final_step);
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
// TESTS
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
