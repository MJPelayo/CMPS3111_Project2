const std = @import("std");
const rl = @import("raylib");
const plot = @import("plot.zig");

const screen_width: i32 = 1000;
const screen_height: i32 = 700;

pub fn displayGraph(graph: plot.Graph) void {
    rl.initWindow(screen_width, screen_height, "CMPS3111 Project 2 - Graph");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        rl.clearBackground(rl.Color.white);
        drawGraph(graph);
        rl.endDrawing();
    }
}

fn drawGraph(graph: plot.Graph) void {
    rl.drawText("CMPS3111 Project 2", 365, 20, 24, rl.Color.black);
    rl.drawText("Graphical Output", 400, 50, 18, rl.Color.dark_gray);
    if (graph.plots.len == 0) return;

    if (graph.plots.len == 1) {
        drawPlotPanel(graph.plots[0], 30, 90, screen_width - 60, screen_height - 120, true, 1);
        return;
    }

    const columns = calculateColumns(graph.plots.len);
    const rows = (graph.plots.len + columns - 1) / columns;
    const panel_width = @divFloor(screen_width - 40, @as(i32, @intCast(columns)));
    const panel_height = @divFloor(screen_height - 105, @as(i32, @intCast(rows)));

    for (graph.plots, 0..) |current_plot, index| {
        const column = index % columns;
        const row = index / columns;
        const x = 20 + @as(i32, @intCast(column)) * panel_width;
        const y = 85 + @as(i32, @intCast(row)) * panel_height;
        drawPlotPanel(current_plot, x + 5, y + 5, panel_width - 10, panel_height - 10, false, index + 1);
    }
}

fn calculateColumns(count: usize) usize {
    if (count <= 2) return count;
    if (count <= 4) return 2;
    if (count <= 9) return 3;
    return 4;
}

fn drawPlotPanel(
    current_plot: plot.Plot,
    panel_x: i32,
    panel_y: i32,
    panel_width: i32,
    panel_height: i32,
    large_panel: bool,
    plot_number: usize,
) void {
    rl.drawRectangleLines(panel_x, panel_y, panel_width, panel_height, rl.Color.dark_gray);

    const kind: []const u8 = switch (current_plot.kind) {
        .bar => "BAR",
        .line => "LINE",
        .grid => "GRID",
        .fill => "FILL",
    };
    const color = switch (current_plot.kind) {
        .bar => rl.Color.blue,
        .line => rl.Color.red,
        .grid => rl.Color.black,
        .fill => rl.Color.green,
    };

    const first = current_plot.first_coordinate;
    var title_buffer: [128:0]u8 = undefined;
    const title: [:0]const u8 = switch (current_plot.kind) {
        .bar => blk: {
            const n = current_plot.number orelse return;
            break :blk std.fmt.bufPrintZ(&title_buffer, "{s} {c}{c},{d} - Graph {d}", .{ kind, first[0], first[1], n, plot_number }) catch return;
        },
        .line => blk: {
            const second = current_plot.second_coordinate orelse return;
            break :blk std.fmt.bufPrintZ(&title_buffer, "{s} {c}{c},{c}{c} - Graph {d}", .{ kind, first[0], first[1], second[0], second[1], plot_number }) catch return;
        },
        .grid, .fill => std.fmt.bufPrintZ(&title_buffer, "{s} {c}{c} - Graph {d}", .{ kind, first[0], first[1], plot_number }) catch return,
    };

    const title_size: i32 = if (large_panel) 22 else if (panel_width < 270) 12 else 16;
    const title_width = rl.measureText(title, title_size);
    rl.drawText(title, panel_x + @divFloor(panel_width - title_width, 2), panel_y + 10, title_size, color);

    const graph_y_offset: i32 = if (large_panel) 55 else 45;
    const graph_height_offset: i32 = if (large_panel) 85 else 65;
    const graph_x = panel_x + 45;
    const graph_y = panel_y + graph_y_offset;
    const graph_width = panel_width - 70;
    const graph_height = panel_height - graph_height_offset;
    if (graph_width <= 50 or graph_height <= 50) return;

    // Preserve the original GRID command's dimensions and coordinate system.
    var grid_width_units: usize = 9;
    var grid_height_units: usize = 9;
    if (current_plot.kind == .grid) {
        grid_width_units = @as(usize, @intCast(first[0] - 'a'));
        grid_height_units = @as(usize, @intCast(first[1] - '0'));
        if (grid_width_units == 0) grid_width_units = 1;
        if (grid_height_units == 0) grid_height_units = 1;
    }

    const cell_width_from_panel = @divFloor(graph_width - 10, @as(i32, @intCast(grid_width_units)));
    const cell_height_from_panel = @divFloor(graph_height - 10, @as(i32, @intCast(grid_height_units)));
    const cell_size = @max(5, @min(cell_width_from_panel, cell_height_from_panel));
    const actual_grid_width = @as(i32, @intCast(grid_width_units)) * cell_size;
    const actual_grid_height = @as(i32, @intCast(grid_height_units)) * cell_size;
    const origin_x = graph_x + @divFloor(graph_width - actual_grid_width, 2);
    const origin_y = graph_y + actual_grid_height + @divFloor(graph_height - actual_grid_height, 2);

    // Point-fill uses the same intersection labels as BAR, LINE and GRID.
    drawCoordinateGrid(origin_x, origin_y, cell_size, grid_width_units, grid_height_units);

    switch (current_plot.kind) {
        .bar => drawBar(current_plot, origin_x, origin_y, cell_size),
        .line => drawLinePlot(current_plot, origin_x, origin_y, cell_size),
        .grid => {},
        .fill => drawFillPoint(current_plot, origin_x, origin_y, cell_size),
    }
}

fn drawCoordinateGrid(
    origin_x: i32,
    origin_y: i32,
    cell_size: i32,
    width_units: usize,
    height_units: usize,
) void {
    const grid_width = @as(i32, @intCast(width_units)) * cell_size;
    const grid_height = @as(i32, @intCast(height_units)) * cell_size;

    var x: usize = 0;
    while (x <= width_units) : (x += 1) {
        const sx = origin_x + @as(i32, @intCast(x)) * cell_size;
        rl.drawLine(sx, origin_y - grid_height, sx, origin_y, rl.Color.black);
    }
    var y: usize = 0;
    while (y <= height_units) : (y += 1) {
        const sy = origin_y - @as(i32, @intCast(y)) * cell_size;
        rl.drawLine(origin_x, sy, origin_x + grid_width, sy, rl.Color.black);
    }

    const x_labels = "abcdefghij";
    x = 0;
    while (x <= width_units) : (x += 1) {
        var letter: [2:0]u8 = .{ x_labels[x], 0 };
        const font_size: i32 = if (cell_size >= 25) 16 else 11;
        const label_width = rl.measureText(&letter, font_size);
        const line_x = origin_x + @as(i32, @intCast(x)) * cell_size;
        rl.drawText(&letter, line_x - @divFloor(label_width, 2), origin_y + 8, font_size, rl.Color.black);
    }
    y = 0;
    while (y <= height_units) : (y += 1) {
        var number_buffer: [3:0]u8 = undefined;
        const number = std.fmt.bufPrintZ(&number_buffer, "{d}", .{y}) catch return;
        const font_size: i32 = if (cell_size >= 25) 16 else 11;
        const line_y = origin_y - @as(i32, @intCast(y)) * cell_size;
        rl.drawText(number, origin_x - 24, line_y - @divFloor(font_size, 2), font_size, rl.Color.black);
    }
}

fn coordinateToScreenX(value: u8, origin_x: i32, cell_size: i32) i32 {
    return origin_x + @as(i32, @intCast(value - 'a')) * cell_size;
}

fn coordinateToScreenY(value: u8, origin_y: i32, cell_size: i32) i32 {
    return origin_y - @as(i32, @intCast(value - '0')) * cell_size;
}

fn drawBar(current_plot: plot.Plot, origin_x: i32, origin_y: i32, cell_size: i32) void {
    const first = current_plot.first_coordinate;
    const width_units = current_plot.number orelse return;
    const x = coordinateToScreenX(first[0], origin_x, cell_size);
    const top_y = coordinateToScreenY(first[1], origin_y, cell_size);
    const width = @as(i32, @intCast(width_units)) * cell_size;
    const height = origin_y - top_y;
    if (width <= 0 or height <= 0) return;

    // Four thick blue edges. Do not fill and do not draw a middle divider.
    const thickness: i32 = 4;
    rl.drawRectangle(x, top_y, width, thickness, rl.Color.blue);
    rl.drawRectangle(x, origin_y - thickness, width, thickness, rl.Color.blue);
    rl.drawRectangle(x, top_y, thickness, height, rl.Color.blue);
    rl.drawRectangle(x + width - thickness, top_y, thickness, height, rl.Color.blue);
}

fn drawLinePlot(current_plot: plot.Plot, origin_x: i32, origin_y: i32, cell_size: i32) void {
    const second = current_plot.second_coordinate orelse return;
    const first = current_plot.first_coordinate;
    const x1 = coordinateToScreenX(first[0], origin_x, cell_size);
    const y1 = coordinateToScreenY(first[1], origin_y, cell_size);
    const x2 = coordinateToScreenX(second[0], origin_x, cell_size);
    const y2 = coordinateToScreenY(second[1], origin_y, cell_size);
    rl.drawLineEx(.{ .x = @floatFromInt(x1), .y = @floatFromInt(y1) }, .{ .x = @floatFromInt(x2), .y = @floatFromInt(y2) }, 4, rl.Color.red);
    rl.drawCircle(x1, y1, 6, rl.Color.black);
    rl.drawCircle(x2, y2, 6, rl.Color.black);
}

// Point-based FILL:
// Draw a green square centered exactly at the
// intersection of the specified X and Y coordinates.

fn drawFillPoint(
    current_plot: plot.Plot,
    origin_x: i32,
    origin_y: i32,
    cell_size: i32,
) void {
    const first = current_plot.first_coordinate;

    const center_x = coordinateToScreenX(
        first[0],
        origin_x,
        cell_size,
    );

    const center_y = coordinateToScreenY(
        first[1],
        origin_y,
        cell_size,
    );

    // Square occupies 60% of one grid cell.
    const marker_size = @max(
        6,
        @divFloor(cell_size * 3, 5),
    );

    // Keep the square centered at the intersection.
    const marker_x = center_x - @divFloor(marker_size, 2);
    const marker_y = center_y - @divFloor(marker_size, 2);

    // Draw the green filled square.
    rl.drawRectangle(
        marker_x,
        marker_y,
        marker_size,
        marker_size,
        rl.Color.green,
    );

    // Black outline for visibility.
    rl.drawRectangleLines(
        marker_x,
        marker_y,
        marker_size,
        marker_size,
        rl.Color.black,
    );
}
