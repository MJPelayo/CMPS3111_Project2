const std = @import("std");
const plot = @import("plot.zig");

const MAX_X: usize = 10;
const MAX_Y: usize = 10;

const X_SCALE: usize = 4;

const Canvas = struct {
    cells: [MAX_Y][MAX_X * X_SCALE]u8,

    fn init() Canvas {
        var canvas = Canvas{
            .cells = undefined,
        };

        for (0..MAX_Y) |y| {
            for (0..MAX_X * X_SCALE) |x| {
                canvas.cells[y][x] = ' ';
            }
        }

        return canvas;
    }

    fn set(
        self: *Canvas,
        x: usize,
        y: usize,
        character: u8,
    ) void {
        if (x >= MAX_X * X_SCALE) {
            return;
        }

        if (y >= MAX_Y) {
            return;
        }

        self.cells[y][x] = character;
    }
};

pub fn displayGraph(
    writer: *std.Io.Writer,
    graph: plot.Graph,
) !void {
    try writer.writeAll(
        \\GRAPHICAL OUTPUT
        \\----------------------------------------
        \\
    );

    if (graph.plots.len == 0) {
        try writer.writeAll(
            \\No graphical commands to display.
            \\
        );

        return;
    }

    for (graph.plots, 0..) |current_plot, index| {
        try writer.print(
            "Plot {d}\n\n",
            .{index + 1},
        );

        switch (current_plot.kind) {
            .bar => {
                try displayBar(
                    writer,
                    current_plot,
                );
            },

            .line => {
                try displayLine(
                    writer,
                    current_plot,
                );
            },

            .grid => {
                try displayGrid(
                    writer,
                    current_plot,
                );
            },

            .fill => {
                try displayFill(
                    writer,
                    current_plot,
                );
            },
        }

        try writer.writeAll("\n");
    }
}

fn displayBar(
    writer: *std.Io.Writer,
    current_plot: plot.Plot,
) !void {
    const x_start = xCoordinateToIndex(
        current_plot.first_coordinate[0],
    );

    const top_y = yCoordinateToValue(
        current_plot.first_coordinate[1],
    );

    const width = current_plot.number orelse 0;

    if (x_start >= MAX_X or
        top_y >= MAX_Y or
        width == 0)
    {
        return;
    }

    // The final number represents the width.
    //
    // Example:
    //
    // bar e4,4
    //
    // starts at E4 and extends four units:
    //
    // E -> F -> G -> H -> I
    //
    // Therefore I is the right boundary.

    var x_end = x_start + width;

    if (x_end >= MAX_X) {
        x_end = MAX_X - 1;
    }

    // Render the complete graph from Y = 9 down to Y = 0.
    var y: usize = MAX_Y;

    while (y > 0) : (y -= 1) {
        const current_y = y - 1;

        try writer.print(
            "{d} | ",
            .{current_y},
        );

        var x: usize = 0;

        while (x < MAX_X) : (x += 1) {
            // Top and bottom horizontal edges.
            if (current_y == top_y or current_y == 0) {
                if (x >= x_start and x <= x_end) {
                    try writer.writeAll("#");
                } else {
                    try writer.writeAll(" ");
                }
            }
            // Vertical edges ONLY exist between Y = 0
            // and the bar's top Y coordinate.
            else if (current_y < top_y and
                current_y > 0 and
                (x == x_start or x == x_end))
            {
                try writer.writeAll("#");
            } else {
                try writer.writeAll(" ");
            }

            // Space between graph coordinates.
            try writer.writeAll("   ");
        }

        try writer.writeAll("\n");
    }

    // X-axis.
    try writer.writeAll(
        "  +",
    );

    var axis_length: usize = 0;

    while (axis_length < MAX_X * 4) : (axis_length += 1) {
        try writer.writeAll("-");
    }

    try writer.writeAll("\n");

    // Full X-coordinate labels.
    try writer.writeAll(
        "    ",
    );

    var label_x: usize = 0;

    while (label_x < MAX_X) : (label_x += 1) {
        const label =
            'A' + @as(u8, @intCast(label_x));

        try writer.print(
            "{c}   ",
            .{label},
        );
    }

    try writer.writeAll("\n");
}

fn displayLine(
    writer: *std.Io.Writer,
    current_plot: plot.Plot,
) !void {
    const second = current_plot.second_coordinate orelse {
        return;
    };

    const first_x = xCoordinateToIndex(
        current_plot.first_coordinate[0],
    );

    const first_y = yCoordinateToValue(
        current_plot.first_coordinate[1],
    );

    const second_x = xCoordinateToIndex(
        second[0],
    );

    const second_y = yCoordinateToValue(
        second[1],
    );

    if (first_x >= MAX_X or
        second_x >= MAX_X or
        first_y >= MAX_Y or
        second_y >= MAX_Y)
    {
        return;
    }

    const min_x =
        if (first_x < second_x)
            first_x
        else
            second_x;

    const max_x =
        if (first_x > second_x)
            first_x
        else
            second_x;

    const min_y =
        if (first_y < second_y)
            first_y
        else
            second_y;

    const max_y =
        if (first_y > second_y)
            first_y
        else
            second_y;

    var y = max_y;

    while (true) {
        try writer.print(
            "{d} | ",
            .{y},
        );

        var x = min_x;

        while (x <= max_x) : (x += 1) {
            if (x == first_x and y == first_y) {
                try writer.writeAll("●");
            } else if (x == second_x and y == second_y) {
                try writer.writeAll("●");
            } else if (pointIsOnLine(
                x,
                y,
                first_x,
                first_y,
                second_x,
                second_y,
            )) {
                try writer.writeAll("*");
            } else {
                try writer.writeAll(" ");
            }

            try writer.writeAll("   ");
        }

        try writer.writeAll("\n");

        if (y == min_y) {
            break;
        }

        y -= 1;
    }

    try writer.writeAll("  +");

    var axis_x = min_x;

    while (axis_x <= max_x) : (axis_x += 1) {
        try writer.writeAll("---");

        if (axis_x == max_x) {
            break;
        }

        try writer.writeAll("-");
    }

    try writer.writeAll("\n");

    try writer.writeAll("    ");

    var label_x = min_x;

    while (label_x <= max_x) : (label_x += 1) {
        const label =
            'A' + @as(u8, @intCast(label_x));

        try writer.print(
            "{c}   ",
            .{label},
        );

        if (label_x == max_x) {
            break;
        }
    }

    try writer.writeAll("\n");

    try writer.print(
        "Start point: {c}{d}\n",
        .{
            current_plot.first_coordinate[0],
            first_y,
        },
    );

    try writer.print(
        "End point: {c}{d}\n",
        .{
            second[0],
            second_y,
        },
    );
}

fn pointIsOnLine(
    x: usize,
    y: usize,
    first_x: usize,
    first_y: usize,
    second_x: usize,
    second_y: usize,
) bool {
    const dx =
        if (second_x >= first_x)
            second_x - first_x
        else
            first_x - second_x;

    const dy =
        if (second_y >= first_y)
            second_y - first_y
        else
            first_y - second_y;

    if (dx == 0) {
        return x == first_x;
    }

    if (dy == 0) {
        return y == first_y;
    }

    if (dx == dy) {
        const distance_x =
            if (x >= first_x)
                x - first_x
            else
                first_x - x;

        const distance_y =
            if (y >= first_y)
                y - first_y
            else
                first_y - y;

        return distance_x == distance_y;
    }

    const left =
        @as(i32, @intCast(x)) -
        @as(i32, @intCast(first_x));

    const right =
        @as(i32, @intCast(y)) -
        @as(i32, @intCast(first_y));

    const x_difference =
        @as(i32, @intCast(second_x)) -
        @as(i32, @intCast(first_x));

    const y_difference =
        @as(i32, @intCast(second_y)) -
        @as(i32, @intCast(first_y));

    return left * y_difference ==
        right * x_difference;
}

fn displayGrid(
    writer: *std.Io.Writer,
    current_plot: plot.Plot,
) !void {
    const x_units =
        xCoordinateToIndex(
            current_plot.first_coordinate[0],
        ) + 1;

    const y_units =
        yCoordinateToValue(
            current_plot.first_coordinate[1],
        );

    if (x_units == 0 or y_units == 0) {
        return;
    }

    try displayGridShape(
        writer,
        x_units,
        y_units,
    );
}

fn displayGridShape(
    writer: *std.Io.Writer,
    x_units: usize,
    y_units: usize,
) !void {
    const width = @min(
        x_units,
        MAX_X,
    );

    const height = @min(
        y_units,
        MAX_Y - 1,
    );

    // Grid rows.
    var y: usize = height;

    while (y > 0) : (y -= 1) {
        try writer.print(
            "{d} | ",
            .{y},
        );

        try drawGridHorizontal(
            writer,
            width,
        );

        try writer.writeAll("\n");

        try writer.writeAll("  | ");

        try drawGridVertical(
            writer,
            width,
        );

        try writer.writeAll("\n");
    }

    // Y = 0 row.
    try writer.writeAll(
        "0 | ",
    );

    try drawGridHorizontal(
        writer,
        width,
    );

    try writer.writeAll("\n");

    // Separate X-axis.
    try writer.writeAll(
        "  +",
    );

    var axis_length: usize = 0;

    while (axis_length < width * 4 + 1) : (axis_length += 1) {
        try writer.writeAll("-");
    }

    try writer.writeAll("\n");

    // X-coordinate labels at the bottom.
    try writer.writeAll("    ");

    var x: usize = 0;

    while (x < width) : (x += 1) {
        const label =
            'a' + @as(u8, @intCast(x));

        try writer.print(
            "{c}   ",
            .{label},
        );
    }

    try writer.writeAll("\n");
}

fn drawGridHorizontal(
    writer: *std.Io.Writer,
    width: usize,
) !void {
    var x: usize = 0;

    while (x < width) : (x += 1) {
        try writer.writeAll(
            "+---",
        );
    }

    try writer.writeAll("+");
}

fn drawGridVertical(
    writer: *std.Io.Writer,
    width: usize,
) !void {
    var x: usize = 0;

    while (x < width) : (x += 1) {
        try writer.writeAll(
            "|   ",
        );
    }

    try writer.writeAll("|");
}

fn displayFill(
    writer: *std.Io.Writer,
    current_plot: plot.Plot,
) !void {
    const fill_x =
        xCoordinateToIndex(
            current_plot.first_coordinate[0],
        );

    const fill_y =
        yCoordinateToValue(
            current_plot.first_coordinate[1],
        );

    if (fill_x >= MAX_X or fill_y >= MAX_Y) {
        return;
    }

    try writer.print(
        "{d} | ",
        .{fill_y},
    );

    var x: usize = 0;

    while (x < MAX_X) : (x += 1) {
        if (x == fill_x) {
            try writer.writeAll(
                "█   ",
            );
        } else {
            try writer.writeAll(
                ".   ",
            );
        }
    }

    try writer.writeAll("\n");

    if (fill_y > 0) {
        var y = fill_y;

        while (y > 0) : (y -= 1) {
            try writer.print(
                "{d} | ",
                .{y - 1},
            );

            x = 0;

            while (x < MAX_X) : (x += 1) {
                try writer.writeAll(
                    ".   ",
                );
            }

            try writer.writeAll("\n");
        }
    }

    try writer.writeAll(
        "0 +-----------------------------------------\n",
    );

    try writer.writeAll(
        "    a   b   c   d   e   f   g   h   i   j\n",
    );
}

fn displayCanvas(
    writer: *std.Io.Writer,
    canvas: *const Canvas,
    x_start: usize,
    x_end: usize,
    max_y: usize,
) !void {
    var y = max_y + 1;

    while (y > 0) : (y -= 1) {
        const row = y - 1;

        try writer.print(
            "{d} | ",
            .{row},
        );

        var x = x_start;

        while (x < x_end) : (x += 1) {
            var cell_x: usize = x * X_SCALE;

            while (cell_x < (x + 1) * X_SCALE) : (cell_x += 1) {
                const character =
                    canvas.cells[row][cell_x];

                if (character == '#') {
                    try writer.writeAll(
                        "█",
                    );
                } else if (character == '*') {
                    try writer.writeAll(
                        "*",
                    );
                } else if (character == 'O') {
                    try writer.writeAll(
                        "●",
                    );
                } else {
                    try writer.writeAll(
                        " ",
                    );
                }
            }
        }

        try writer.writeAll("\n");
    }

    try writer.writeAll(
        "0 +----------------------------------------\n",
    );

    try writer.writeAll(
        "    a   b   c   d   e   f   g   h   i   j\n",
    );
}

fn xCoordinateToIndex(
    coordinate: u8,
) usize {
    return @as(
        usize,
        coordinate - 'a',
    );
}

fn yCoordinateToValue(
    coordinate: u8,
) usize {
    return @as(
        usize,
        coordinate - '0',
    );
}

test "coordinate conversion" {
    try std.testing.expectEqual(
        @as(usize, 0),
        xCoordinateToIndex('a'),
    );

    try std.testing.expectEqual(
        @as(usize, 5),
        xCoordinateToIndex('f'),
    );

    try std.testing.expectEqual(
        @as(usize, 1),
        yCoordinateToValue('1'),
    );

    try std.testing.expectEqual(
        @as(usize, 6),
        yCoordinateToValue('6'),
    );
}
