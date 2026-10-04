const std = @import("std");

pub const DerivationError = error{
    InvalidCoordinate,
    InvalidNumber,
};

// ============================================================
// Display the leftmost derivation for a BAR plot.
//
// Input example:
//
//     start bar a1,5 end
//
// Output:
//
//     <graph>
//     ⇒ start <plot_stmts> end
//     ⇒ start <plot> end
//     ⇒ start bar <x><y>,<y> end
//     ⇒ start bar a<y>,<y> end
//     ⇒ start bar a1,<y> end
//     ⇒ start bar a1,5 end
// ============================================================

pub fn displayBarDerivation(
    writer: *std.Io.Writer,
    coordinate: []const u8,
    width: u8,
) !void {
    // --------------------------------------------------------
    // Validate the coordinate.
    //
    // A coordinate must contain:
    //
    //     letter + digit
    //
    // Example:
    //
    //     a1
    // --------------------------------------------------------

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

    // --------------------------------------------------------
    // Validate the bar width.
    //
    // The grammar allows one digit:
    //
    // <y> → 0 | 1 | ... | 9
    // --------------------------------------------------------

    if (width > 9) {
        return error.InvalidNumber;
    }

    // --------------------------------------------------------
    // Initial grammar symbol.
    //
    // <graph>
    // --------------------------------------------------------

    try printStep(
        writer,
        "<graph>",
    );

    // --------------------------------------------------------
    // Expand <graph>.
    //
    // <graph> → start <plot_stmts> end
    // --------------------------------------------------------

    try printStep(
        writer,
        "start <plot_stmts> end",
    );

    // --------------------------------------------------------
    // Expand <plot_stmts>.
    //
    // <plot_stmts> → <plot>
    // --------------------------------------------------------

    try printStep(
        writer,
        "start <plot> end",
    );

    // --------------------------------------------------------
    // Expand <plot>.
    //
    // <plot> → bar <x><y>,<y>
    // --------------------------------------------------------

    try printStep(
        writer,
        "start bar <x><y>,<y> end",
    );

    // --------------------------------------------------------
    // Expand <x>.
    //
    // <x> → a | b | ... | j
    //
    // We replace <x> with the actual coordinate letter.
    // --------------------------------------------------------

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

    // --------------------------------------------------------
    // Expand the first <y>.
    //
    // <y> → 0 | 1 | ... | 9
    // --------------------------------------------------------

    const step_y = try std.fmt.bufPrint(
        &step_buffer,
        "start bar {c}{c},<y> end",
        .{ x, y },
    );

    try printStep(
        writer,
        step_y,
    );

    // --------------------------------------------------------
    // Expand the second <y>.
    // --------------------------------------------------------

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

test "reject invalid derivation coordinate" {
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

test "reject invalid coordinate length" {
    var output_buffer: [4096]u8 = undefined;

    var writer = std.Io.Writer.fixed(
        &output_buffer,
    );

    try std.testing.expectError(
        error.InvalidCoordinate,
        displayBarDerivation(
            &writer,
            "a",
            5,
        ),
    );
}
