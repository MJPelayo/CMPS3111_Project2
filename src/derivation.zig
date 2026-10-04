const std = @import("std");

pub const DerivationError = error{
    InvalidCoordinate,
    InvalidNumber,
};

// ============================================================
// Display the leftmost derivation for a BAR plot.
//
// Grammar:
//
// <plot> → bar <x><y>,<y>
//
// Example:
//
// start bar a1,5 end
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

    // --------------------------------------------------------
    // <graph>
    // --------------------------------------------------------

    try printStep(
        writer,
        "<graph>",
    );

    // <graph> → start <plot_stmts> end
    try printStep(
        writer,
        "start <plot_stmts> end",
    );

    // <plot_stmts> → <plot>
    try printStep(
        writer,
        "start <plot> end",
    );

    // <plot> → bar <x><y>,<y>
    try printStep(
        writer,
        "start bar <x><y>,<y> end",
    );

    // <x> → actual x
    var step_buffer: [256]u8 = undefined;

    const step_x = try std.fmt.bufPrint(
        &step_buffer,
        "start bar {c}<y>,<y> end",
        .{x},
    );

    try printStep(
        writer,
        step_x,
    );

    // First <y> → actual y
    const step_y = try std.fmt.bufPrint(
        &step_buffer,
        "start bar {c}{c},<y> end",
        .{ x, y },
    );

    try printStep(
        writer,
        step_y,
    );

    // Second <y> → actual width
    const final_step = try std.fmt.bufPrint(
        &step_buffer,
        "start bar {c}{c},{d} end",
        .{ x, y, width },
    );

    try printStep(
        writer,
        final_step,
    );
}

// ============================================================
// Display the leftmost derivation for a LINE plot.
//
// Grammar:
//
// <plot> → line <x><y>,<x><y>
//
// Example:
//
// start line a1,b2 end
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

    // <graph>
    try printStep(
        writer,
        "<graph>",
    );

    // <graph> → start <plot_stmts> end
    try printStep(
        writer,
        "start <plot_stmts> end",
    );

    // <plot_stmts> → <plot>
    try printStep(
        writer,
        "start <plot> end",
    );

    // <plot> → line <x><y>,<x><y>
    try printStep(
        writer,
        "start line <x><y>,<x><y> end",
    );

    var step_buffer: [256]u8 = undefined;

    // Expand first <x>.
    const step_first_x = try std.fmt.bufPrint(
        &step_buffer,
        "start line {c}<y>,<x><y> end",
        .{first_x},
    );

    try printStep(
        writer,
        step_first_x,
    );

    // Expand first <y>.
    const step_first_y = try std.fmt.bufPrint(
        &step_buffer,
        "start line {c}{c},<x><y> end",
        .{ first_x, first_y },
    );

    try printStep(
        writer,
        step_first_y,
    );

    // Expand second <x>.
    const step_second_x = try std.fmt.bufPrint(
        &step_buffer,
        "start line {c}{c},{c}<y> end",
        .{
            first_x,
            first_y,
            second_x,
        },
    );

    try printStep(
        writer,
        step_second_x,
    );

    // Expand second <y>.
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

    try printStep(
        writer,
        final_step,
    );
}

// ============================================================
// Display the leftmost derivation for a GRID plot.
//
// Grammar:
//
// <plot> → grid <x><y>
//
// Example:
//
// start grid c4 end
// ============================================================

pub fn displayGridDerivation(
    writer: *std.Io.Writer,
    coordinate: []const u8,
) !void {
    try validateCoordinate(coordinate);

    const x = coordinate[0];
    const y = coordinate[1];

    // <graph>
    try printStep(
        writer,
        "<graph>",
    );

    // <graph> → start <plot_stmts> end
    try printStep(
        writer,
        "start <plot_stmts> end",
    );

    // <plot_stmts> → <plot>
    try printStep(
        writer,
        "start <plot> end",
    );

    // <plot> → grid <x><y>
    try printStep(
        writer,
        "start grid <x><y> end",
    );

    var step_buffer: [256]u8 = undefined;

    // Expand <x>.
    const step_x = try std.fmt.bufPrint(
        &step_buffer,
        "start grid {c}<y> end",
        .{x},
    );

    try printStep(
        writer,
        step_x,
    );

    // Expand <y>.
    const final_step = try std.fmt.bufPrint(
        &step_buffer,
        "start grid {c}{c} end",
        .{ x, y },
    );

    try printStep(
        writer,
        final_step,
    );
}

// ============================================================
// Display the leftmost derivation for a FILL plot.
//
// Grammar:
//
// <plot> → fill <x><y>
//
// Example:
//
// start fill e5 end
// ============================================================

pub fn displayFillDerivation(
    writer: *std.Io.Writer,
    coordinate: []const u8,
) !void {
    try validateCoordinate(coordinate);

    const x = coordinate[0];
    const y = coordinate[1];

    // <graph>
    try printStep(
        writer,
        "<graph>",
    );

    // <graph> → start <plot_stmts> end
    try printStep(
        writer,
        "start <plot_stmts> end",
    );

    // <plot_stmts> → <plot>
    try printStep(
        writer,
        "start <plot> end",
    );

    // <plot> → fill <x><y>
    try printStep(
        writer,
        "start fill <x><y> end",
    );

    var step_buffer: [256]u8 = undefined;

    // Expand <x>.
    const step_x = try std.fmt.bufPrint(
        &step_buffer,
        "start fill {c}<y> end",
        .{x},
    );

    try printStep(
        writer,
        step_x,
    );

    // Expand <y>.
    const final_step = try std.fmt.bufPrint(
        &step_buffer,
        "start fill {c}{c} end",
        .{ x, y },
    );

    try printStep(
        writer,
        final_step,
    );
}

// ============================================================
// Coordinate validation
// ============================================================
//
// A valid coordinate is:
//
//     a0 ... j9
//
// The first character must be a-j.
// The second character must be 0-9.
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
