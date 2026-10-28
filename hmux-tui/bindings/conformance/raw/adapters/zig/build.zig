const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const hmux_tui = b.addModule("hmux_tui", .{
        .root_source_file = b.path("../../../../zig/src/hmux.zig"),
        .target = target,
        .optimize = optimize,
    });
    const adapter = b.createModule(.{
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });
    adapter.addImport("hmux_tui", hmux_tui);

    const executable = b.addExecutable(.{
        .name = "hmux-conformance-zig",
        .root_module = adapter,
    });
    b.installArtifact(executable);
}
