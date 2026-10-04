const std = @import("std");

pub const PlotKind = enum {
    bar,
    line,
    grid,
    fill,
};

pub const Plot = struct {
    kind: PlotKind,
    first_coordinate: [2]u8,
    second_coordinate: ?[2]u8,
    number: ?u8,
};

pub const Graph = struct {
    plots: []const Plot,
};
