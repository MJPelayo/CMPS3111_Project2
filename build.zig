const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "cmps3111_project2",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const raylib_dependency = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport(
        "raylib",
        raylib_dependency.module("raylib"),
    );

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step(
        "run",
        "Run the CMPS3111 Project 2 program",
    );

    run_step.dependOn(&run_cmd.step);
}
