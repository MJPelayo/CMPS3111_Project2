const std = @import("std");
const rl = @import("raylib");
const plot = @import("plot.zig");

pub fn displayGraph(graph: plot.Graph) void {
    const screen_width = 1000;
    const screen_height = 700;

    rl.initWindow(
        screen_width,
        screen_height,
        "CMPS3111 Project 2 - Graph",
    );

    defer rl.closeWindow();

    rl.setTargetFPS(60);

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.white);

        drawGraph(graph);
    }
}

fn drawGraph(graph: plot.Graph) void {
    const screen_width: i32 = 1000;
    const screen_height: i32 = 700;

    rl.drawText(
        "CMPS3111 Project 2",
        365,
        20,
        24,
        rl.Color.black,
    );

    rl.drawText(
        "Graphical Output",
        400,
        50,
        18,
        rl.Color.dark_gray,
    );

    if (graph.plots.len == 0) {
        return;
    }

    // --------------------------------------------------------
    // One plot:
    //
    // Use the large single-graph layout.
    // --------------------------------------------------------

    if (graph.plots.len == 1) {
        const current_plot = graph.plots[0];

        drawPlotPanel(
            current_plot,
            30,
            90,
            screen_width - 60,
            screen_height - 120,
            true,
            1,
        );

        return;
    }

    // --------------------------------------------------------
    // Multiple plots:
    //
    // Panels are displayed in the exact order in which the
    // plots appeared in the input sentence.
    //
    // Example:
    //
    // 1. BAR    2. LINE
    // 3. GRID   4. FILL
    // --------------------------------------------------------

    const plot_count = graph.plots.len;

    const columns = calculateColumns(plot_count);
    const rows = (plot_count + columns - 1) / columns;

    const panel_area_x: i32 = 20;
    const panel_area_y: i32 = 85;

    const panel_area_width: i32 =
        screen_width - 40;

    const panel_area_height: i32 =
        screen_height - 105;

    const panel_width =
        @divFloor(
            panel_area_width,
            @as(i32, @intCast(columns)),
        );

    const panel_height =
        @divFloor(
            panel_area_height,
            @as(i32, @intCast(rows)),
        );

    var index: usize = 0;

    while (index < plot_count) : (index += 1) {
        const column =
            index % columns;

        const row =
            index / columns;

        const panel_x =
            panel_area_x +
            @as(i32, @intCast(column)) *
                panel_width;

        const panel_y =
            panel_area_y +
            @as(i32, @intCast(row)) *
                panel_height;

        drawPlotPanel(
            graph.plots[index],
            panel_x + 5,
            panel_y + 5,
            panel_width - 10,
            panel_height - 10,
            false,
            index + 1,
        );
    }
}

// ============================================================
// Calculate a balanced number of columns.
//
// Examples:
//
// 2 plots  -> 2 columns
// 3 plots  -> 2 columns
// 4 plots  -> 2 columns
// 5 plots  -> 3 columns
// 6 plots  -> 3 columns
// 7 plots  -> 3 columns
// 8 plots  -> 3 columns
// 9 plots  -> 3 columns
// 10 plots -> 4 columns
// ============================================================

fn calculateColumns(plot_count: usize) usize {
    if (plot_count <= 2) {
        return plot_count;
    }

    if (plot_count <= 4) {
        return 2;
    }

    if (plot_count <= 9) {
        return 3;
    }

    return 4;
}

// ============================================================
// Draw one complete plot panel.
// ============================================================

fn drawPlotPanel(
    current_plot: plot.Plot,
    panel_x: i32,
    panel_y: i32,
    panel_width: i32,
    panel_height: i32,
    large_panel: bool,
    plot_number: usize,
) void {
    rl.drawRectangleLines(
        panel_x,
        panel_y,
        panel_width,
        panel_height,
        rl.Color.dark_gray,
    );

    // --------------------------------------------------------
    // Plot title
    // --------------------------------------------------------

    var title_buffer: [32:0]u8 = undefined;

    const title =
        switch (current_plot.kind) {
            .bar => "BAR",
            .line => "LINE",
            .grid => "GRID",
            .fill => "FILL",
        };

    const title_text =
        std.fmt.bufPrintZ(
            &title_buffer,
            "{d}. {s}",
            .{
                plot_number,
                title,
            },
        ) catch unreachable;

    const title_size: i32 =
        if (large_panel) 22 else 18;

    const title_width: i32 =
        switch (current_plot.kind) {
            .bar => 60,
            .line => 66,
            .grid => 62,
            .fill => 60,
        };

    const title_x =
        panel_x +
        @divFloor(panel_width, 2) -
        @divFloor(title_width, 2);

    rl.drawText(
        title_text,
        title_x,
        panel_y + 10,
        title_size,
        rl.Color.black,
    );

    // --------------------------------------------------------
    // Graph drawing area.
    // --------------------------------------------------------

    const graph_y_offset: i32 =
        if (large_panel) 55 else 45;

    const graph_height_offset: i32 =
        if (large_panel) 85 else 65;

    const graph_x: i32 =
        panel_x + 45;

    const graph_y: i32 =
        panel_y + graph_y_offset;

    const graph_width: i32 =
        panel_width - 70;

    const graph_height: i32 =
        panel_height - graph_height_offset;

    if (graph_width <= 50 or graph_height <= 50) {
        return;
    }

    // --------------------------------------------------------
    // Coordinate dimensions.
    //
    // BNF:
    //
    // X = a through j
    // Y = 0 through 9
    //
    // Therefore there are 9 intervals in each direction.
    // --------------------------------------------------------

    var grid_width_units: usize = 9;
    var grid_height_units: usize = 9;

    // --------------------------------------------------------
    // A GRID command defines a smaller coordinate area.
    //
    // Example:
    //
    // grid e5
    //
    // X = a through e
    // Y = 0 through 5
    // --------------------------------------------------------

    if (current_plot.kind == .grid) {
        grid_width_units =
            @as(
                usize,
                @intCast(
                    current_plot.first_coordinate[0] - 'a',
                ),
            );

        grid_height_units =
            @as(
                usize,
                @intCast(
                    current_plot.first_coordinate[1] - '0',
                ),
            );

        if (grid_width_units == 0) {
            grid_width_units = 1;
        }

        if (grid_height_units == 0) {
            grid_height_units = 1;
        }
    }

    // --------------------------------------------------------
    // Calculate cell size.
    // --------------------------------------------------------

    const available_width: i32 =
        graph_width - 10;

    const available_height: i32 =
        graph_height - 10;

    const cell_width_from_panel =
        @divFloor(
            available_width,
            @as(
                i32,
                @intCast(grid_width_units),
            ),
        );

    const cell_height_from_panel =
        @divFloor(
            available_height,
            @as(
                i32,
                @intCast(grid_height_units),
            ),
        );

    var cell_size: i32 =
        if (cell_width_from_panel < cell_height_from_panel)
            cell_width_from_panel
        else
            cell_height_from_panel;

    if (cell_size < 5) {
        cell_size = 5;
    }

    // --------------------------------------------------------
    // Calculate actual graph dimensions.
    // --------------------------------------------------------

    const actual_grid_width =
        @as(i32, @intCast(grid_width_units)) *
        cell_size;

    const actual_grid_height =
        @as(i32, @intCast(grid_height_units)) *
        cell_size;

    const origin_x =
        graph_x +
        @divFloor(
            graph_width - actual_grid_width,
            2,
        );

    const origin_y =
        graph_y +
        actual_grid_height +
        @divFloor(
            graph_height - actual_grid_height,
            2,
        );

    // --------------------------------------------------------
    // Draw coordinate grid.
    // --------------------------------------------------------

    drawCoordinateGrid(
        origin_x,
        origin_y,
        cell_size,
        cell_size,
        grid_width_units,
        grid_height_units,
    );

    // --------------------------------------------------------
    // Draw the actual plot.
    // --------------------------------------------------------

    switch (current_plot.kind) {
        .bar => drawBar(
            current_plot,
            origin_x,
            origin_y,
            cell_size,
            cell_size,
        ),

        .line => drawLinePlot(
            current_plot,
            origin_x,
            origin_y,
            cell_size,
            cell_size,
        ),

        .grid => {},

        .fill => drawFillPlot(
            current_plot,
            origin_x,
            origin_y,
            cell_size,
            cell_size,
        ),
    }
}

// ============================================================
// Draw coordinate grid.
// ============================================================

fn drawCoordinateGrid(
    origin_x: i32,
    origin_y: i32,
    cell_width: i32,
    cell_height: i32,
    width_units: usize,
    height_units: usize,
) void {
    const grid_width =
        @as(i32, @intCast(width_units)) *
        cell_width;

    const grid_height =
        @as(i32, @intCast(height_units)) *
        cell_height;

    // --------------------------------------------------------
    // Vertical lines.
    // --------------------------------------------------------

    var x: usize = 0;

    while (x <= width_units) : (x += 1) {
        const screen_x =
            origin_x +
            @as(
                i32,
                @intCast(
                    x *
                        @as(
                            usize,
                            @intCast(cell_width),
                        ),
                ),
            );

        rl.drawLine(
            screen_x,
            origin_y - grid_height,
            screen_x,
            origin_y,
            rl.Color.light_gray,
        );
    }

    // --------------------------------------------------------
    // Horizontal lines.
    // --------------------------------------------------------

    var y: usize = 0;

    while (y <= height_units) : (y += 1) {
        const screen_y =
            origin_y -
            @as(
                i32,
                @intCast(
                    y *
                        @as(
                            usize,
                            @intCast(cell_height),
                        ),
                ),
            );

        rl.drawLine(
            origin_x,
            screen_y,
            origin_x + grid_width,
            screen_y,
            rl.Color.light_gray,
        );
    }

    // --------------------------------------------------------
    // X-axis.
    // --------------------------------------------------------

    rl.drawLine(
        origin_x,
        origin_y,
        origin_x + grid_width,
        origin_y,
        rl.Color.black,
    );

    // --------------------------------------------------------
    // Y-axis.
    // --------------------------------------------------------

    rl.drawLine(
        origin_x,
        origin_y - grid_height,
        origin_x,
        origin_y,
        rl.Color.black,
    );

    // --------------------------------------------------------
    // X labels.
    //
    // Exactly a through j.
    // --------------------------------------------------------

    const x_labels = "abcdefghij";

    var x_label: usize = 0;

    while (x_label <= width_units) : (x_label += 1) {
        const screen_x =
            origin_x +
            @as(
                i32,
                @intCast(
                    x_label *
                        @as(
                            usize,
                            @intCast(cell_width),
                        ),
                ),
            ) -
            4;

        var label_buffer: [2:0]u8 = .{
            x_labels[x_label],
            0,
        };

        rl.drawText(
            &label_buffer,
            screen_x,
            origin_y + 8,
            if (cell_width >= 25) 16 else 11,
            rl.Color.black,
        );
    }

    // --------------------------------------------------------
    // Y labels.
    //
    // Exactly 0 through 9.
    // --------------------------------------------------------

    var y_label: usize = 0;

    while (y_label <= height_units) : (y_label += 1) {
        const screen_y =
            origin_y -
            @as(
                i32,
                @intCast(
                    y_label *
                        @as(
                            usize,
                            @intCast(cell_height),
                        ),
                ),
            ) -
            6;

        var number_buffer: [3:0]u8 = undefined;

        const number_text =
            std.fmt.bufPrintZ(
                &number_buffer,
                "{d}",
                .{y_label},
            ) catch unreachable;

        rl.drawText(
            number_text,
            origin_x - 24,
            screen_y,
            if (cell_height >= 25) 16 else 11,
            rl.Color.black,
        );
    }
}

// ============================================================
// Coordinate conversion.
// ============================================================

fn coordinateToScreenX(
    coordinate: u8,
    origin_x: i32,
    cell_width: i32,
) i32 {
    const column =
        @as(
            i32,
            @intCast(
                coordinate - 'a',
            ),
        );

    return origin_x +
        column *
            cell_width;
}

fn coordinateToScreenY(
    coordinate: u8,
    origin_y: i32,
    cell_height: i32,
) i32 {
    const row =
        @as(
            i32,
            @intCast(
                coordinate - '0',
            ),
        );

    return origin_y -
        row *
            cell_height;
}

// ============================================================
// BAR
// ============================================================

fn drawBar(
    current_plot: plot.Plot,
    origin_x: i32,
    origin_y: i32,
    cell_width: i32,
    cell_height: i32,
) void {
    const first_x =
        coordinateToScreenX(
            current_plot.first_coordinate[0],
            origin_x,
            cell_width,
        );

    const top_y =
        coordinateToScreenY(
            current_plot.first_coordinate[1],
            origin_y,
            cell_height,
        );

    const width_units =
        current_plot.number orelse return;

    const width =
        @as(i32, @intCast(width_units)) *
        cell_width;

    const height =
        origin_y -
        top_y;

    rl.drawRectangleLines(
        first_x,
        top_y,
        width,
        height,
        rl.Color.blue,
    );
}

// ============================================================
// LINE
// ============================================================

fn drawLinePlot(
    current_plot: plot.Plot,
    origin_x: i32,
    origin_y: i32,
    cell_width: i32,
    cell_height: i32,
) void {
    const second_coordinate =
        current_plot.second_coordinate orelse return;

    const first_x =
        coordinateToScreenX(
            current_plot.first_coordinate[0],
            origin_x,
            cell_width,
        );

    const first_y =
        coordinateToScreenY(
            current_plot.first_coordinate[1],
            origin_y,
            cell_height,
        );

    const second_x =
        coordinateToScreenX(
            second_coordinate[0],
            origin_x,
            cell_width,
        );

    const second_y =
        coordinateToScreenY(
            second_coordinate[1],
            origin_y,
            cell_height,
        );

    rl.drawLineEx(
        .{
            .x = @floatFromInt(first_x),
            .y = @floatFromInt(first_y),
        },
        .{
            .x = @floatFromInt(second_x),
            .y = @floatFromInt(second_y),
        },
        4,
        rl.Color.red,
    );

    rl.drawCircle(
        first_x,
        first_y,
        6,
        rl.Color.black,
    );

    rl.drawCircle(
        second_x,
        second_y,
        6,
        rl.Color.black,
    );
}

// ============================================================
// FILL
//
// The coordinate identifies the exact point where the fill
// marker is placed.
//
// Example:
//
// fill e4
//
// places a filled square centered exactly at e4.
//
// This means every valid coordinate from a0 through j9 has
// its own unique graphical position.
//
// No boundary adjustments are necessary.
// ============================================================

fn drawFillPlot(
    current_plot: plot.Plot,
    origin_x: i32,
    origin_y: i32,
    cell_width: i32,
    cell_height: i32,
) void {
    const fill_x =
        coordinateToScreenX(
            current_plot.first_coordinate[0],
            origin_x,
            cell_width,
        );

    const fill_y =
        coordinateToScreenY(
            current_plot.first_coordinate[1],
            origin_y,
            cell_height,
        );

    // --------------------------------------------------------
    // The filled marker is deliberately smaller than a grid
    // cell so the coordinate intersection remains visible.
    // --------------------------------------------------------

    var marker_size =
        if (cell_width < cell_height)
            cell_width
        else
            cell_height;

    marker_size =
        @divFloor(marker_size * 3, 5);

    if (marker_size < 8) {
        marker_size = 8;
    }

    // --------------------------------------------------------
    // Center the filled square exactly on the coordinate.
    // --------------------------------------------------------

    const marker_x =
        fill_x -
        @divFloor(marker_size, 2);

    const marker_y =
        fill_y -
        @divFloor(marker_size, 2);

    // --------------------------------------------------------
    // Filled square.
    // --------------------------------------------------------

    rl.drawRectangle(
        marker_x,
        marker_y,
        marker_size,
        marker_size,
        rl.Color.green,
    );

    // --------------------------------------------------------
    // Thin outline so the marker remains clearly visible
    // against the grid.
    // --------------------------------------------------------

    rl.drawRectangleLines(
        marker_x,
        marker_y,
        marker_size,
        marker_size,
        rl.Color.black,
    );
}
