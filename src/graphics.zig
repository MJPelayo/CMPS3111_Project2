const std = @import("std");
const rl = @import("raylib");
const plot = @import("plot.zig");

// Shared, integer-pixel drawing surface. One grammar program produces one picture.
// The existing lexer, parser, derivation, and tree are unchanged.
const units: i32 = 9;
const unit_px: i32 = 45;
const side: i32 = units * unit_px + 1;
const pixel_count: usize = @intCast(side * side);
// Axis endpoints are configurable by the GRID command.
var axis_x_units: i32 = units;
var axis_y_units: i32 = units;
const origin_x: i32 = 160;
const origin_y: i32 = 677;
const window_w: i32 = 1100;
const window_h: i32 = 790;

const ink = rl.Color{ .r = 26, .g = 43, .b = 67, .a = 255 };
const muted = rl.Color{ .r = 88, .g = 105, .b = 128, .a = 255 };
const background = rl.Color{ .r = 245, .g = 248, .b = 252, .a = 255 };
const panel = rl.Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
const divider_color = rl.Color{ .r = 218, .g = 226, .b = 238, .a = 255 };
const accent = rl.Color{ .r = 35, .g = 105, .b = 205, .a = 255 };

// Font is loaded after initWindow (texture/context needed). Windows and Ubuntu
// use their normal installed fonts; no font file needs to be distributed.
var ui_font: rl.Font = undefined;
var owns_font: bool = false;

fn loadUiFont() void {
    ui_font = rl.getFontDefault() catch unreachable;
    owns_font = false;
    const candidates = [_][:0]const u8{
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
        "C:/Windows/Fonts/segoeui.ttf",
        "C:/Windows/Fonts/arial.ttf",
    };
    for (candidates) |path| {
        if (rl.loadFontEx(path, 48, null)) |font| {
            ui_font = font;
            owns_font = true;
            break;
        } else |_| {}
    }
}

fn text(s: [:0]const u8, x: i32, y: i32, size: f32, color: rl.Color) void {
    rl.drawTextEx(ui_font, s, .{ .x = @floatFromInt(x), .y = @floatFromInt(y) }, size, 0.3, color);
}

fn panelBox(x: i32, y: i32, w: i32, h: i32) void {
    rl.drawRectangle(x, y, w, h, panel);
    rl.drawRectangleLines(x, y, w, h, divider_color);
}

const empty: u8 = 0;
const bar_boundary: u8 = 1;
const line_boundary: u8 = 2;
const fill_color: u8 = 3;
const axis_boundary: u8 = 4;

// Static storage avoids repeated heap allocation and preserves the composition
// while Raylib redraws the window at 60 frames per second.
var pixels: [pixel_count]u8 = undefined;
var seen: [pixel_count]u8 = undefined;
var queue: [pixel_count]u32 = undefined;

const RenderInfo = struct {
    fills_applied: usize = 0,
    background_fills: usize = 0,
    fills_on_boundaries: usize = 0,
    bars: usize = 0,
    lines: usize = 0,
};

pub fn displayGraph(graph: plot.Graph) void {
    @memset(pixels[0..], empty);
    // Match the plotting extent to the commands. For example, a single
    // `line a1,f6` uses A-F and 0-6. This makes the end of that line meet
    // the graph's top/right corner, creating a bounded lower region.
    // A GRID command explicitly contributes its requested axis endpoints.
    // Include all BAR and LINE geometry so multiple commands stay visible.
    // FILL alone uses the full coordinate canvas because it has no shape.
    axis_x_units = 0;
    axis_y_units = 0;
    var has_geometry = false;
    for (graph.plots) |command| {
        switch (command.kind) {
            .bar => {
                has_geometry = true;
                const start_x = @as(i32, command.first_coordinate[0]) - @as(i32, 'a');
                const height = @as(i32, command.first_coordinate[1]) - @as(i32, '0');
                const width = @as(i32, command.number orelse 0);
                axis_x_units = @max(axis_x_units, @min(units, start_x + width));
                axis_y_units = @max(axis_y_units, height);
            },
            .line => {
                has_geometry = true;
                axis_x_units = @max(axis_x_units, @as(i32, command.first_coordinate[0]) - @as(i32, 'a'));
                axis_y_units = @max(axis_y_units, @as(i32, command.first_coordinate[1]) - @as(i32, '0'));
                if (command.second_coordinate) |second| {
                    axis_x_units = @max(axis_x_units, @as(i32, second[0]) - @as(i32, 'a'));
                    axis_y_units = @max(axis_y_units, @as(i32, second[1]) - @as(i32, '0'));
                }
            },
            .grid => {
                has_geometry = true;
                axis_x_units = @max(axis_x_units, @as(i32, command.first_coordinate[0]) - @as(i32, 'a'));
                axis_y_units = @max(axis_y_units, @as(i32, command.first_coordinate[1]) - @as(i32, '0'));
            },
            .fill => {},
        }
    }
    if (!has_geometry) {
        axis_x_units = units;
        axis_y_units = units;
    }
    // Frame/border of active plotting rectangle. The user only sees the
    // X/Y axes; no horizontal or vertical interior grid lines are shown.
    drawRasterLine(0, 0, axis_x_units * unit_px, 0, axis_boundary, 1);
    drawRasterLine(0, 0, 0, axis_y_units * unit_px, axis_boundary, 1);
    const info = compose(graph);

    // Resizable decorated window shows native minimize, maximize and close
    // buttons on desktops that support normal window-manager decorations.
    rl.setConfigFlags(.{ .window_resizable = true });
    rl.initWindow(window_w, window_h, "CMPS3111 Project 2 - Graphical Interpreter");
    defer rl.closeWindow();
    rl.setWindowMinSize(760, 560);
    loadUiFont();
    defer if (owns_font) rl.unloadFont(ui_font);
    rl.setTargetFPS(60);
    while (!rl.windowShouldClose()) {
        // Fit the complete original layout into resized/maximized windows.
        const sw: f32 = @floatFromInt(rl.getScreenWidth());
        const sh: f32 = @floatFromInt(rl.getScreenHeight());
        const zoom = @min(sw / @as(f32, @floatFromInt(window_w)), sh / @as(f32, @floatFromInt(window_h)));
        const offset_x = (sw - @as(f32, @floatFromInt(window_w)) * zoom) / 2.0;
        const offset_y = (sh - @as(f32, @floatFromInt(window_h)) * zoom) / 2.0;
        rl.beginDrawing();
        rl.clearBackground(background);
        rl.beginMode2D(.{
            .offset = .{ .x = offset_x, .y = offset_y },
            .target = .{ .x = 0, .y = 0 },
            .rotation = 0,
            .zoom = zoom,
        });
        drawUi(graph, info);
        drawRaster();
        drawAxes();
        rl.endMode2D();
        rl.endDrawing();
    }
}

fn compose(graph: plot.Graph) RenderInfo {
    var info = RenderInfo{};
    for (graph.plots) |cmd| {
        switch (cmd.kind) {
            .bar => {
                const n = cmd.number orelse continue;
                const x = coordX(cmd.first_coordinate[0]);
                const y = coordY(cmd.first_coordinate[1]);
                const width = @as(i32, n) * unit_px;
                if (width <= 0 or y <= 0) continue;
                const x_end = @min(x + width, units * unit_px);
                // Lecturer: top-left = (x,height), bottom-left = (x,0),
                // second number = horizontal width in coordinate units.
                drawRasterLine(x, 0, x, y, bar_boundary, 3);
                drawRasterLine(x, y, x_end, y, bar_boundary, 3);
                drawRasterLine(x_end, y, x_end, 0, bar_boundary, 3);
                drawRasterLine(x_end, 0, x, 0, bar_boundary, 3);
                info.bars += 1;
            },
            .line => {
                const second = cmd.second_coordinate orelse continue;
                drawRasterLine(coordX(cmd.first_coordinate[0]), coordY(cmd.first_coordinate[1]), coordX(second[0]), coordY(second[1]), line_boundary, 3);
                info.lines += 1;
            },
            .grid => {
                // GRID is axes only; extents were resolved before command execution.
                // No internal vertical or horizontal grid lines are added.
            },
            .fill => {
                const result = floodFillEnclosed(
                    coordX(cmd.first_coordinate[0]),
                    coordY(cmd.first_coordinate[1]),
                );
                switch (result) {
                    .filled => info.fills_applied += 1,
                    .filled_background => {
                        info.fills_applied += 1;
                        info.background_fills += 1;
                    },
                    .boundary => info.fills_on_boundaries += 1,
                }
            },
        }
    }
    return info;
}

const FillResult = enum { filled, filled_background, boundary };

// Flood-fill the connected available space containing (x,y).
// The active plot extent acts as the outer canvas boundary. A LINE segment
// that reaches the extent on two sides (e.g., a1 to f6 in an A-F/0-6 view)
// therefore separates the upper and lower regions without inventing an
// invisible extension of the line. BAR outlines block fill normally.
fn floodFillEnclosed(x: i32, y: i32) FillResult {
    if (!insideActive(x, y)) return .boundary;
    const start = index(x, y);
    if (pixels[start] == fill_color) return .filled;
    if (pixels[start] != empty) return .boundary;
    @memset(seen[0..], 0);
    var front: usize = 0;
    var back: usize = 1;
    queue[0] = @intCast(start);
    seen[start] = 1;
    var reaches_edge = false;
    while (front < back) : (front += 1) {
        const pos: usize = @intCast(queue[front]);
        const cx: i32 = @intCast(pos % @as(usize, @intCast(side)));
        const cy: i32 = @intCast(pos / @as(usize, @intCast(side)));
        if (cx == axis_x_units * unit_px or cy == axis_y_units * unit_px or cx == 0 or cy == 0) reaches_edge = true;
        const neighbors = [_][2]i32{ .{ cx - 1, cy }, .{ cx + 1, cy }, .{ cx, cy - 1 }, .{ cx, cy + 1 } };
        for (neighbors) |p| {
            if (!insideActive(p[0], p[1])) continue;
            const next = index(p[0], p[1]);
            if (pixels[next] != empty or seen[next] != 0) continue;
            seen[next] = 1;
            queue[back] = @intCast(next);
            back += 1;
        }
    }
    for (queue[0..back]) |q| pixels[@intCast(q)] = fill_color;
    return if (reaches_edge) .filled_background else .filled;
}

fn coordX(c: u8) i32 {
    return (@as(i32, c) - 'a') * unit_px;
}
fn coordY(c: u8) i32 {
    return (@as(i32, c) - '0') * unit_px;
}
fn inside(x: i32, y: i32) bool {
    return x >= 0 and y >= 0 and x < side and y < side;
}
fn insideActive(x: i32, y: i32) bool {
    return inside(x, y) and x <= axis_x_units * unit_px and y <= axis_y_units * unit_px;
}
fn index(x: i32, y: i32) usize {
    return @intCast(y * side + x);
}

fn paintDisk(x: i32, y: i32, color: u8, radius: i32) void {
    var dy: i32 = -radius;
    while (dy <= radius) : (dy += 1) {
        var dx: i32 = -radius;
        while (dx <= radius) : (dx += 1) {
            if (dx * dx + dy * dy > radius * radius) continue;
            const px = x + dx;
            const py = y + dy;
            if (inside(px, py)) pixels[index(px, py)] = color;
        }
    }
}

fn drawRasterLine(x0: i32, y0: i32, x1: i32, y1: i32, color: u8, radius: i32) void {
    var x = x0;
    var y = y0;
    const dx = @abs(x1 - x0);
    const dy = @abs(y1 - y0);
    const sx: i32 = if (x0 < x1) 1 else -1;
    const sy: i32 = if (y0 < y1) 1 else -1;
    var error_value: i32 = @as(i32, @intCast(dx)) - @as(i32, @intCast(dy));
    while (true) {
        paintDisk(x, y, color, radius);
        if (x == x1 and y == y1) break;
        const twice = 2 * error_value;
        if (twice > -@as(i32, @intCast(dy))) {
            error_value -= @intCast(dy);
            x += sx;
        }
        if (twice < @as(i32, @intCast(dx))) {
            error_value += @intCast(dx);
            y += sy;
        }
    }
}

fn colorOf(value: u8) rl.Color {
    return switch (value) {
        bar_boundary => rl.Color.blue,
        line_boundary => rl.Color.red,
        fill_color => rl.Color.green,
        axis_boundary => rl.Color.black,
        else => rl.Color.white,
    };
}

fn drawRaster() void {
    // Horizontal runs, rather than a Raylib draw call for every filled pixel.
    var y: i32 = 0;
    while (y <= axis_y_units * unit_px) : (y += 1) {
        var x: i32 = 0;
        while (x <= axis_x_units * unit_px) {
            const value = pixels[index(x, y)];
            if (value == empty) {
                x += 1;
                continue;
            }
            const run_start = x;
            x += 1;
            while (x <= axis_x_units * unit_px and pixels[index(x, y)] == value) : (x += 1) {}
            rl.drawRectangle(origin_x + run_start, origin_y - y, x - run_start, 1, colorOf(value));
        }
    }
}

fn drawAxes() void {
    // Axes extend to the largest necessary coordinate (including GRID).
    // No internal grid lines are ever displayed.
    const x_end = origin_x + axis_x_units * unit_px;
    const y_top = origin_y - axis_y_units * unit_px;
    rl.drawLineEx(.{ .x = @floatFromInt(origin_x), .y = @floatFromInt(origin_y) }, .{ .x = @floatFromInt(x_end + 12), .y = @floatFromInt(origin_y) }, 2, ink);
    rl.drawLineEx(.{ .x = @floatFromInt(origin_x), .y = @floatFromInt(origin_y) }, .{ .x = @floatFromInt(origin_x), .y = @floatFromInt(y_top - 12) }, 2, ink);

    var x: i32 = 0;
    while (x <= axis_x_units) : (x += 1) {
        const px = origin_x + x * unit_px;
        rl.drawLine(px, origin_y, px, origin_y + 6, muted);
        const letter: [2:0]u8 = .{ @intCast(@as(i32, 'a') + x), 0 };
        text(&letter, px - 6, origin_y + 11, 15, ink);
    }
    var y: i32 = 0;
    while (y <= axis_y_units) : (y += 1) {
        const py = origin_y - y * unit_px;
        rl.drawLine(origin_x - 6, py, origin_x, py, muted);
        var number_buffer: [4:0]u8 = undefined;
        const label = std.fmt.bufPrintZ(&number_buffer, "{d}", .{y}) catch unreachable;
        text(label, origin_x - 31, py - 9, 15, ink);
    }
    text("X", x_end + 21, origin_y - 9, 17, ink);
    text("Y", origin_x - 7, y_top - 36, 17, ink);
}

fn legendItem(y: i32, color: rl.Color, label: [:0]const u8) void {
    rl.drawRectangle(737, y + 2, 17, 17, color);
    text(label, 765, y, 17, ink);
}

fn drawUi(graph: plot.Graph, info: RenderInfo) void {
    // Header and subtitle.
    rl.drawRectangle(0, 0, window_w, 100, panel);
    rl.drawLine(0, 99, window_w, 99, divider_color);
    rl.drawRectangle(35, 27, 5, 43, accent);
    text("CMPS3111  |  GRAPHICAL INTERPRETER", 57, 24, 26, ink);
    text("Project 2  |  Single coordinate system", 57, 61, 18, muted);

    // Graph card and legend card.
    panelBox(34, 119, 671, 602);
    panelBox(721, 119, 345, 602);
    text("GRAPH OUTPUT", 64, 139, 19, ink);
    text("Commands in order  |  Adaptive axes  |  No grid lines", 64, 168, 16, muted);
    rl.drawLine(58, 199, 680, 199, divider_color);
    text("LEGEND", 737, 143, 20, ink);
    text("Drawing commands", 737, 171, 15, muted);
    rl.drawLine(737, 205, 1049, 205, divider_color);
    legendItem(229, rl.Color.blue, "BAR  -  Blue outline");
    legendItem(273, rl.Color.red, "LINE  -  Red segment");
    legendItem(317, rl.Color.green, "FILL  -  Green region");
    legendItem(361, rl.Color.black, "GRID  -  X and Y axes");
    rl.drawLine(737, 416, 1049, 416, divider_color);
    text("SESSION SUMMARY", 737, 428, 18, ink);
    var summary: [160:0]u8 = undefined;
    const count = std.fmt.bufPrintZ(&summary, "Total: {d}   Bars: {d}   Lines: {d}", .{ graph.plots.len, info.bars, info.lines }) catch unreachable;
    text(count, 737, 458, 14, muted);
    var fill_buffer: [160:0]u8 = undefined;
    const fills = std.fmt.bufPrintZ(&fill_buffer, "Fills: {d}   Canvas: {d}   Border: {d}", .{ info.fills_applied, info.background_fills, info.fills_on_boundaries }) catch unreachable;
    text(fills, 737, 481, 14, muted);

    rl.drawLine(737, 509, 1049, 509, divider_color);
    text("COMMANDS IN ORDER", 737, 519, 16, ink);

    // Show the exact parsed commands rather than only a numerical count.
    // Reserve the last list row for an overflow message on long programs.
    const max_visible: usize = 7;
    const visible = @min(graph.plots.len, max_visible);
    for (graph.plots[0..visible], 0..) |cmd, i| {
        var command_buffer: [100:0]u8 = undefined;
        const command: [:0]const u8 = switch (cmd.kind) {
            .bar => std.fmt.bufPrintZ(&command_buffer, "{d}. bar {c}{c},{d}", .{ i + 1, cmd.first_coordinate[0], cmd.first_coordinate[1], cmd.number orelse 0 }) catch unreachable,
            .line => blk: {
                const second = cmd.second_coordinate orelse .{ '?', '?' };
                break :blk std.fmt.bufPrintZ(&command_buffer, "{d}. line {c}{c},{c}{c}", .{ i + 1, cmd.first_coordinate[0], cmd.first_coordinate[1], second[0], second[1] }) catch unreachable;
            },
            .grid => std.fmt.bufPrintZ(&command_buffer, "{d}. grid {c}{c}", .{ i + 1, cmd.first_coordinate[0], cmd.first_coordinate[1] }) catch unreachable,
            .fill => std.fmt.bufPrintZ(&command_buffer, "{d}. fill {c}{c}", .{ i + 1, cmd.first_coordinate[0], cmd.first_coordinate[1] }) catch unreachable,
        };
        text(command, 743, 546 + @as(i32, @intCast(i)) * 20, 14, ink);
    }
    if (graph.plots.len > max_visible) {
        var remainder_buffer: [64:0]u8 = undefined;
        const more = std.fmt.bufPrintZ(&remainder_buffer, "+ {d} more commands", .{graph.plots.len - max_visible}) catch unreachable;
        text(more, 743, 686, 13, muted);
    } else {
        text("Close window to continue", 743, 686, 13, muted);
    }
    text("University of Belize  |  CMPS3111 Project 2", 36, 748, 15, muted);
}
