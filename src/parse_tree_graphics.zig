const std = @import("std");
const rl = @import("raylib");
const plot = @import("plot.zig");

// Graphical BNF parse tree. The tree is reconstructed from the validated
// Graph, so no grammar rules or parser behavior are changed.
const max_nodes = 4096;
const none = std.math.maxInt(usize);

// Load an antialiased TrueType font, falling back to Raylib's default.
var viewer_font: rl.Font = undefined;
var viewer_font_loaded = false;

fn drawUiText(label: [:0]const u8, x: i32, y: i32, size: i32, color: rl.Color) void {
    if (viewer_font_loaded) {
        rl.drawTextEx(viewer_font, label, .{ .x = @floatFromInt(x), .y = @floatFromInt(y) }, @floatFromInt(size), 0.5, color);
    } else {
        rl.drawText(label, x, y, size, color);
    }
}

fn textWidth(label: [:0]const u8, size: i32) f32 {
    if (viewer_font_loaded) return rl.measureTextEx(viewer_font, label, @floatFromInt(size), 0.5).x;
    return @floatFromInt(rl.measureText(label, size));
}

const Node = struct {
    label: [32:0]u8 = std.mem.zeroes([32:0]u8),
    parent: usize = none,
    x: f32 = 0,
    y: f32 = 0,
};

const Tree = struct {
    nodes: [max_nodes]Node = undefined,
    count: usize = 0,
    next_leaf: f32 = 0,
    max_depth: usize = 0,

    fn add(self: *Tree, parent: usize, label: []const u8) !usize {
        if (self.count == max_nodes) return error.TreeTooLarge;
        const id = self.count;
        self.count += 1;
        self.nodes[id] = .{ .parent = parent };
        const n = @min(label.len, 31);
        @memcpy(self.nodes[id].label[0..n], label[0..n]);
        self.nodes[id].label[n] = 0;
        return id;
    }

    fn coordinate(self: *Tree, parent: usize, value: [2]u8) !void {
        const x = try self.add(parent, "<x>");
        _ = try self.add(x, value[0..1]);
        const y = try self.add(parent, "<y>");
        _ = try self.add(y, value[1..2]);
    }

    fn plotNode(self: *Tree, parent: usize, p: plot.Plot) !void {
        const id = try self.add(parent, "<plot>");
        switch (p.kind) {
            .bar => {
                _ = try self.add(id, "bar");
                try self.coordinate(id, p.first_coordinate);
                _ = try self.add(id, ",");
                const y = try self.add(id, "<y>");
                const number = p.number orelse 0;
                var digit: [1]u8 = .{number + '0'};
                _ = try self.add(y, &digit);
            },
            .line => {
                _ = try self.add(id, "line");
                try self.coordinate(id, p.first_coordinate);
                _ = try self.add(id, ",");
                try self.coordinate(id, p.second_coordinate orelse return error.InvalidPlot);
            },
            .grid, .fill => {
                _ = try self.add(id, if (p.kind == .grid) "grid" else "fill");
                try self.coordinate(id, p.first_coordinate);
            },
        }
    }

    fn statements(self: *Tree, parent: usize, plots: []const plot.Plot) !void {
        if (plots.len == 0) return error.InvalidPlot;
        const id = try self.add(parent, "<plot_stmts>");
        try self.plotNode(id, plots[0]);
        if (plots.len > 1) {
            _ = try self.add(id, ";");
            try self.statements(id, plots[1..]);
        }
    }

    fn build(self: *Tree, graph: plot.Graph) !void {
        const root = try self.add(none, "<graph>");
        _ = try self.add(root, "start");
        try self.statements(root, graph.plots);
        _ = try self.add(root, "end");
        _ = self.layout(root, 0);
    }

    // Leaves get consecutive horizontal slots; each parent is centered
    // between its immediate first and last children.
    fn layout(self: *Tree, id: usize, depth: usize) f32 {
        self.max_depth = @max(self.max_depth, depth);
        var first: ?f32 = null;
        var last: f32 = 0;
        for (0..self.count) |child| {
            if (self.nodes[child].parent != id) continue;
            const child_x = self.layout(child, depth + 1);
            if (first == null) first = child_x;
            last = child_x;
        }
        const x = if (first) |f| (f + last) / 2 else blk: {
            const value = self.next_leaf * 112;
            self.next_leaf += 1;
            break :blk value;
        };
        self.nodes[id].x = x;
        self.nodes[id].y = @as(f32, @floatFromInt(depth)) * 94;
        return x;
    }
};

const navy = rl.Color{ .r = 29, .g = 62, .b = 100, .a = 255 };
const blue = rl.Color{ .r = 218, .g = 233, .b = 255, .a = 255 };
const green = rl.Color{ .r = 220, .g = 248, .b = 224, .a = 255 };
const purple = rl.Color{ .r = 237, .g = 221, .b = 255, .a = 255 };
const orange = rl.Color{ .r = 255, .g = 237, .b = 213, .a = 255 };
const ink = rl.Color{ .r = 27, .g = 42, .b = 65, .a = 255 };
const panel = rl.Color{ .r = 239, .g = 245, .b = 253, .a = 255 };

fn labelOf(node: *const Node) [:0]const u8 {
    return std.mem.sliceTo(&node.label, 0);
}

fn isCommand(label: []const u8) bool {
    return std.mem.eql(u8, label, "bar") or std.mem.eql(u8, label, "line") or
        std.mem.eql(u8, label, "grid") or std.mem.eql(u8, label, "fill");
}

fn nodeColor(label: []const u8) rl.Color {
    if (std.mem.eql(u8, label, "<graph>")) return blue;
    if (std.mem.eql(u8, label, "<plot>")) return orange;
    if (label.len > 1 and label[0] == '<') return blue;
    if (isCommand(label)) return purple;
    if (label.len == 1 and label[0] != ',' and label[0] != ';') return orange;
    return green;
}

fn borderColor(label: []const u8) rl.Color {
    if (isCommand(label)) return rl.Color{ .r = 129, .g = 53, .b = 207, .a = 255 };
    if (label.len > 1 and label[0] == '<') return rl.Color{ .r = 33, .g = 107, .b = 224, .a = 255 };
    if (label.len == 1 and label[0] != ',' and label[0] != ';') return rl.Color{ .r = 225, .g = 132, .b = 40, .a = 255 };
    return rl.Color{ .r = 48, .g = 148, .b = 78, .a = 255 };
}

fn roundedBox(x: f32, y: f32, w: f32, h: f32, fill: rl.Color, outline: rl.Color) void {
    const r = rl.Rectangle{ .x = x, .y = y, .width = w, .height = h };
    rl.drawRectangleRounded(r, 0.18, 6, fill);
    rl.drawRectangleRoundedLinesEx(r, 0.18, 6, 1.6, outline);
}

fn textCentered(label: [:0]const u8, cx: f32, cy: f32, size: i32, color: rl.Color) void {
    const width = textWidth(label, size);
    drawUiText(label, @intFromFloat(cx - width / 2), @intFromFloat(cy - @as(f32, @floatFromInt(size)) / 2), size, color);
}

fn commandSummary(p: plot.Plot, index: usize, buf: *[96:0]u8) [:0]const u8 {
    const first = p.first_coordinate;
    return switch (p.kind) {
        .bar => std.fmt.bufPrintZ(buf, "{d}. BAR {c}{c},{d}", .{ index + 1, first[0], first[1], p.number orelse 0 }) catch "BAR",
        .line => blk: {
            const second = p.second_coordinate orelse first;
            break :blk std.fmt.bufPrintZ(buf, "{d}. LINE {c}{c},{c}{c}", .{ index + 1, first[0], first[1], second[0], second[1] }) catch "LINE";
        },
        .grid => std.fmt.bufPrintZ(buf, "{d}. GRID {c}{c}", .{ index + 1, first[0], first[1] }) catch "GRID",
        .fill => std.fmt.bufPrintZ(buf, "{d}. FILL {c}{c}", .{ index + 1, first[0], first[1] }) catch "FILL",
    };
}

pub fn displayGraphParseTree(graph: plot.Graph) void {
    var tree: Tree = .{};
    tree.build(graph) catch return;

    const screen_w: i32 = 1400;
    const screen_h: i32 = 900;
    // Request standard OS window controls (minimize, maximize, restore).
    rl.setConfigFlags(.{ .window_resizable = true });
    rl.initWindow(screen_w, screen_h, "CMPS3111 Project 2 - BNF Parse Tree Viewer");
    defer rl.closeWindow();
    rl.setTargetFPS(60);
    // The raylib-zig 6 binding returns an error union for loadFontEx.
    // Only store and unload the custom font when loading succeeds.
    // On failure, drawUiText/textWidth use Raylib's built-in font.
    viewer_font_loaded = false;
    if (rl.loadFontEx("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 48, null)) |loaded_font| {
        viewer_font = loaded_font;
        viewer_font_loaded = true;
    } else |_| {
        viewer_font_loaded = false;
    }
    defer {
        if (viewer_font_loaded) rl.unloadFont(viewer_font);
        viewer_font_loaded = false;
    }

    // Keep the header fixed; pan and zoom only the tree canvas.
    const canvas_top: f32 = 205;
    const canvas_bottom: f32 = 765;
    const canvas_left: f32 = 24;
    const canvas_right: f32 = 1376;
    const tree_width = @max(1.0, tree.next_leaf * 112);
    const tree_height = @as(f32, @floatFromInt(tree.max_depth)) * 94 + 48;
    const fit_zoom = @min(1.0, @min(1270.0 / tree_width, 500.0 / tree_height));
    var zoom = @max(0.65, fit_zoom);
    var pan = rl.Vector2{ .x = 700 - (tree_width - 112) * zoom / 2, .y = 245 };
    const reset_zoom = zoom;
    const reset_pan = pan;

    while (!rl.windowShouldClose()) {
        // F11 switches between fullscreen and the normal decorated window.
        // Closing the window still returns control to main.zig.
        if (rl.isKeyPressed(.f11)) {
            rl.toggleFullscreen();
        }

        // Use a fixed 1400x900 design canvas, scaled uniformly to fit the
        // current window. This keeps panels, text, and tree aligned when
        // maximizing, resizing, or entering fullscreen.
        const actual_w: f32 = @floatFromInt(rl.getScreenWidth());
        const actual_h: f32 = @floatFromInt(rl.getScreenHeight());
        const ui_scale = @max(0.01, @min(actual_w / 1400.0, actual_h / 900.0));
        const offset_x = (actual_w - 1400.0 * ui_scale) / 2.0;
        const offset_y = (actual_h - 900.0 * ui_scale) / 2.0;
        const ui_camera = rl.Camera2D{
            .offset = .{ .x = offset_x, .y = offset_y },
            .target = .{ .x = 0, .y = 0 },
            .rotation = 0,
            .zoom = ui_scale,
        };
        const raw_mouse = rl.getMousePosition();
        const mouse = rl.Vector2{
            .x = (raw_mouse.x - offset_x) / ui_scale,
            .y = (raw_mouse.y - offset_y) / ui_scale,
        };
        const inside = mouse.x >= canvas_left and mouse.x <= canvas_right and
            mouse.y >= canvas_top and mouse.y <= canvas_bottom;
        if (inside) {
            const wheel = rl.getMouseWheelMove();
            if (wheel != 0) {
                const old_zoom = zoom;
                zoom = std.math.clamp(zoom * (if (wheel > 0) @as(f32, 1.15) else @as(f32, 0.87)), 0.05, 3.0);
                pan.x = mouse.x - (mouse.x - pan.x) * zoom / old_zoom;
                pan.y = mouse.y - (mouse.y - pan.y) * zoom / old_zoom;
            }
            if (rl.isMouseButtonDown(.left)) {
                const delta = rl.getMouseDelta();
                pan.x += delta.x / ui_scale;
                pan.y += delta.y / ui_scale;
            }
        }
        if (rl.isKeyPressed(.r)) {
            zoom = reset_zoom;
            pan = reset_pan;
        }

        rl.beginDrawing();
        rl.clearBackground(rl.Color.white);
        rl.beginMode2D(ui_camera);
        rl.drawRectangle(0, 0, screen_w, 54, navy);
        drawUiText("BNF Parse Tree Viewer", 26, 13, 28, rl.Color.white);

        roundedBox(22, 68, 635, 122, panel, blue);
        roundedBox(670, 68, 365, 122, panel, blue);
        roundedBox(1048, 68, 330, 122, panel, blue);
        drawUiText("Input String", 39, 79, 21, ink);
        drawUiText("Controls", 687, 79, 21, ink);
        drawUiText("Node Legend", 1065, 79, 21, ink);
        drawUiText("Mouse wheel: Zoom  |  Left-drag: Pan", 687, 112, 15, ink);
        drawUiText("R: Reset view  |  X: Return to program", 687, 140, 15, ink);

        var input: [512:0]u8 = std.mem.zeroes([512:0]u8);
        var used: usize = 0;
        const prefix = "start ";
        @memcpy(input[0..prefix.len], prefix);
        used = prefix.len;
        for (graph.plots, 0..) |p, i| {
            var command_buf: [96:0]u8 = undefined;
            const full = commandSummary(p, i, &command_buf);
            const space = std.mem.indexOfScalar(u8, full, ' ') orelse 0;
            const part = full[@min(space + 1, full.len)..];
            if (used + part.len + 6 >= 511) break;
            if (i > 0) {
                input[used] = ';';
                used += 1;
            }
            for (part, 0..) |ch, j| input[used + j] = std.ascii.toLower(ch);
            used += part.len;
        }
        if (used + 4 < 511) {
            @memcpy(input[used .. used + 4], " end");
            used += 4;
            input[used] = 0;
        }
        drawUiText(&input, 39, 121, 16, ink);

        const legend_labels = [_][:0]const u8{ "Nonterminal", "Terminal / symbol", "Command", "Coordinate value" };
        const legend_colors = [_]rl.Color{ blue, green, purple, orange };
        for (legend_labels, 0..) |label, i| {
            const yy: f32 = 105 + @as(f32, @floatFromInt(i)) * 20;
            roundedBox(1066, yy, 23, 15, legend_colors[i], ink);
            drawUiText(label, 1098, @intFromFloat(yy), 14, ink);
        }

        // Scissor prevents a large tree from covering the fixed UI panels.
        rl.beginScissorMode(@intFromFloat(canvas_left), @intFromFloat(canvas_top), @intFromFloat(canvas_right - canvas_left), @intFromFloat(canvas_bottom - canvas_top));
        for (tree.nodes[0..tree.count]) |node| {
            if (node.parent == none) continue;
            const parent = tree.nodes[node.parent];
            const start = rl.Vector2{ .x = pan.x + parent.x * zoom, .y = pan.y + (parent.y + 19) * zoom };
            const end = rl.Vector2{ .x = pan.x + node.x * zoom, .y = pan.y + (node.y - 19) * zoom };
            rl.drawLineEx(start, end, @max(1.0, 2.0 * zoom), ink);
        }
        for (tree.nodes[0..tree.count]) |*node| {
            const cx = pan.x + node.x * zoom;
            const cy = pan.y + node.y * zoom;
            const label = labelOf(node);
            const width: f32 = if (std.mem.eql(u8, label, "<plot_stmts>")) 120 else 94;
            const w = width * zoom;
            const h = 38 * zoom;
            roundedBox(cx - w / 2, cy - h / 2, w, h, nodeColor(label), borderColor(label));
            const font_size: i32 = @max(5, @as(i32, @intFromFloat(17 * zoom)));
            textCentered(label, cx, cy, font_size, ink);
        }
        rl.endScissorMode();

        roundedBox(22, 775, 650, 110, panel, blue);
        drawUiText("Parsed Structure", 38, 785, 19, ink);
        var count_buf: [64:0]u8 = undefined;
        const count_text = std.fmt.bufPrintZ(&count_buf, "Total Plots: {d}", .{graph.plots.len}) catch "Plots";
        drawUiText(count_text, 38, 813, 16, ink);
        for (graph.plots[0..@min(graph.plots.len, 4)], 0..) |p, i| {
            var command_buf: [96:0]u8 = undefined;
            const summary = commandSummary(p, i, &command_buf);
            const x: i32 = if (i < 2) 195 else 395;
            const y: i32 = if (i % 2 == 0) 813 else 842;
            drawUiText(summary, x, y, 15, ink);
        }
        roundedBox(688, 775, 690, 110, green, rl.Color{ .r = 65, .g = 157, .b = 85, .a = 255 });
        drawUiText("Complete BNF Structure", 710, 792, 21, ink);
        drawUiText("Exact grammar hierarchy, including recursive statements and terminals.", 710, 830, 16, ink);
        rl.endMode2D();
        rl.endDrawing();
    }
}
