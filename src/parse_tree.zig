const std = @import("std");
const lexer = @import("lexer.zig");
const parser = @import("parser.zig");
const plot = @import("plot.zig");

pub const ParseTreeError = error{
    InvalidInput,
};

pub fn displayGraphParseTree(
    writer: *std.Io.Writer,
    tokens: []const lexer.Token,
) !void {
    var plots: [100]plot.Plot = undefined;

    var graph_parser = parser.Parser.init(tokens);

    const graph = graph_parser.parseGraphInto(&plots) catch {
        return error.InvalidInput;
    };

    if (graph.plots.len == 0) {
        return error.InvalidInput;
    }

    try writer.writeAll("<graph>\n");

    // <graph> has three children:
    //
    // ├── start
    // ├── <plot_stmts>
    // └── end
    //
    // Because <plot_stmts> has a sibling below it (end),
    // its children need to continue the vertical branch.
    try writer.writeAll("├── start\n");
    try writer.writeAll("├── <plot_stmts>\n");

    try displayPlotStatements(
        writer,
        graph.plots,
        "│   ",
    );

    try writer.writeAll("└── end\n");
}

fn displayPlotStatements(
    writer: *std.Io.Writer,
    plots: []const plot.Plot,
    prefix: []const u8,
) !void {
    if (plots.len == 0) {
        return;
    }

    const current = plots[0];
    const has_remaining = plots.len > 1;

    // A <plot_stmts> node can contain:
    //
    // <plot>
    //
    // OR
    //
    // <plot>
    // ;
    // <plot_stmts>
    //
    // Therefore, when more plots remain, the current
    // <plot> is not the final child.
    if (has_remaining) {
        try writer.print(
            "{s}├── <plot>\n",
            .{prefix},
        );
    } else {
        try writer.print(
            "{s}└── <plot>\n",
            .{prefix},
        );
    }

    // Determine the prefix used by the children of <plot>.
    //
    // If <plot> has another sibling, keep the vertical
    // branch visible.
    //
    // If <plot> is the last child, use spaces instead.
    var plot_prefix_buffer: [128]u8 = undefined;

    const plot_prefix = if (has_remaining)
        try std.fmt.bufPrint(
            &plot_prefix_buffer,
            "{s}│   ",
            .{prefix},
        )
    else
        try std.fmt.bufPrint(
            &plot_prefix_buffer,
            "{s}    ",
            .{prefix},
        );

    try displayPlot(
        writer,
        current,
        plot_prefix,
    );

    if (has_remaining) {
        // Separator between plots.
        try writer.print(
            "{s}├── ;\n",
            .{prefix},
        );

        // Recursive <plot_stmts>.
        try writer.print(
            "{s}└── <plot_stmts>\n",
            .{prefix},
        );

        // The recursive <plot_stmts> is the last child,
        // so its descendants use spaces rather than a
        // continuing vertical branch at this level.
        var next_prefix_buffer: [128]u8 = undefined;

        const next_prefix = try std.fmt.bufPrint(
            &next_prefix_buffer,
            "{s}    ",
            .{prefix},
        );

        try displayPlotStatements(
            writer,
            plots[1..],
            next_prefix,
        );
    }
}

fn displayPlot(
    writer: *std.Io.Writer,
    current: plot.Plot,
    prefix: []const u8,
) !void {
    switch (current.kind) {
        .bar => {
            const width = current.number orelse {
                return error.InvalidInput;
            };

            try writer.print(
                "{s}├── bar\n",
                .{prefix},
            );

            try writer.print(
                "{s}├── <x> → {c}\n",
                .{ prefix, current.first_coordinate[0] },
            );

            try writer.print(
                "{s}├── <y> → {c}\n",
                .{ prefix, current.first_coordinate[1] },
            );

            try writer.print(
                "{s}├── ,\n",
                .{prefix},
            );

            try writer.print(
                "{s}└── <y> → {d}\n",
                .{ prefix, width },
            );
        },

        .line => {
            const second = current.second_coordinate orelse {
                return error.InvalidInput;
            };

            try writer.print(
                "{s}├── line\n",
                .{prefix},
            );

            try writer.print(
                "{s}├── <x> → {c}\n",
                .{ prefix, current.first_coordinate[0] },
            );

            try writer.print(
                "{s}├── <y> → {c}\n",
                .{ prefix, current.first_coordinate[1] },
            );

            try writer.print(
                "{s}├── ,\n",
                .{prefix},
            );

            try writer.print(
                "{s}├── <x> → {c}\n",
                .{ prefix, second[0] },
            );

            try writer.print(
                "{s}└── <y> → {c}\n",
                .{ prefix, second[1] },
            );
        },

        .grid => {
            try writer.print(
                "{s}├── grid\n",
                .{prefix},
            );

            try writer.print(
                "{s}├── <x> → {c}\n",
                .{ prefix, current.first_coordinate[0] },
            );

            try writer.print(
                "{s}└── <y> → {c}\n",
                .{ prefix, current.first_coordinate[1] },
            );
        },

        .fill => {
            try writer.print(
                "{s}├── fill\n",
                .{prefix},
            );

            try writer.print(
                "{s}├── <x> → {c}\n",
                .{ prefix, current.first_coordinate[0] },
            );

            try writer.print(
                "{s}└── <y> → {c}\n",
                .{ prefix, current.first_coordinate[1] },
            );
        },
    }
}

test "display parse tree for single bar plot" {
    const input = "start bar a1,5 end";

    var tokens: [20]lexer.Token = undefined;

    const token_count = try lexer.tokenize(
        input,
        &tokens,
    );

    var output_buffer: [4096]u8 = undefined;

    var writer = std.Io.Writer.fixed(
        &output_buffer,
    );

    try displayGraphParseTree(
        &writer,
        tokens[0..token_count],
    );

    const output = output_buffer[0..writer.end];

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "<graph>\n",
        ) != null,
    );

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "├── start\n",
        ) != null,
    );

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "├── <plot_stmts>\n",
        ) != null,
    );

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "│   └── <plot>\n",
        ) != null,
    );

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "│       ├── bar\n",
        ) != null,
    );

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "│       ├── <x> → a\n",
        ) != null,
    );

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "│       ├── <y> → 1\n",
        ) != null,
    );

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "│       ├── ,\n",
        ) != null,
    );

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "│       └── <y> → 5\n",
        ) != null,
    );

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "└── end\n",
        ) != null,
    );
}

test "display parse tree for multiple plots" {
    const input = "start bar a1,5;grid c4 end";

    var tokens: [30]lexer.Token = undefined;

    const token_count = try lexer.tokenize(
        input,
        &tokens,
    );

    var output_buffer: [4096]u8 = undefined;

    var writer = std.Io.Writer.fixed(
        &output_buffer,
    );

    try displayGraphParseTree(
        &writer,
        tokens[0..token_count],
    );

    const output = output_buffer[0..writer.end];

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "├── <plot_stmts>\n",
        ) != null,
    );

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "│   ├── <plot>\n",
        ) != null,
    );

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "│   ├── ;\n",
        ) != null,
    );

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "│   └── <plot_stmts>\n",
        ) != null,
    );

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "│       └── <plot>\n",
        ) != null,
    );

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "│           ├── grid\n",
        ) != null,
    );

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "│           ├── <x> → c\n",
        ) != null,
    );

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "│           └── <y> → 4\n",
        ) != null,
    );
}

test "display parse tree for line plot" {
    const input = "start line a1,b2 end";

    var tokens: [20]lexer.Token = undefined;

    const token_count = try lexer.tokenize(
        input,
        &tokens,
    );

    var output_buffer: [4096]u8 = undefined;

    var writer = std.Io.Writer.fixed(
        &output_buffer,
    );

    try displayGraphParseTree(
        &writer,
        tokens[0..token_count],
    );

    const output = output_buffer[0..writer.end];

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "├── line\n",
        ) != null,
    );

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "<x> → a",
        ) != null,
    );

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "<x> → b",
        ) != null,
    );
}

test "display parse tree for grid plot" {
    const input = "start grid c4 end";

    var tokens: [20]lexer.Token = undefined;

    const token_count = try lexer.tokenize(
        input,
        &tokens,
    );

    var output_buffer: [4096]u8 = undefined;

    var writer = std.Io.Writer.fixed(
        &output_buffer,
    );

    try displayGraphParseTree(
        &writer,
        tokens[0..token_count],
    );

    const output = output_buffer[0..writer.end];

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "├── grid\n",
        ) != null,
    );

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "<x> → c",
        ) != null,
    );

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "<y> → 4",
        ) != null,
    );
}

test "display parse tree for fill plot" {
    const input = "start fill e5 end";

    var tokens: [20]lexer.Token = undefined;

    const token_count = try lexer.tokenize(
        input,
        &tokens,
    );

    var output_buffer: [4096]u8 = undefined;

    var writer = std.Io.Writer.fixed(
        &output_buffer,
    );

    try displayGraphParseTree(
        &writer,
        tokens[0..token_count],
    );

    const output = output_buffer[0..writer.end];

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "├── fill\n",
        ) != null,
    );

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "<x> → e",
        ) != null,
    );

    try std.testing.expect(
        std.mem.indexOf(
            u8,
            output,
            "<y> → 5",
        ) != null,
    );
}

test "reject invalid parse tree input" {
    const input = "start bar a1 end";

    var tokens: [20]lexer.Token = undefined;

    const token_count = try lexer.tokenize(
        input,
        &tokens,
    );

    var output_buffer: [4096]u8 = undefined;

    var writer = std.Io.Writer.fixed(
        &output_buffer,
    );

    try std.testing.expectError(
        error.InvalidInput,
        displayGraphParseTree(
            &writer,
            tokens[0..token_count],
        ),
    );
}
