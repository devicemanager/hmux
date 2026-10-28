const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const hmux_tui = b.addModule("hmux_tui", .{
        .root_source_file = b.path("src/hmux.zig"),
        .target = target,
        .optimize = optimize,
    });

    const unit_tests = b.addTest(.{
        .name = "hmux-tui-zig-tests",
        .root_module = hmux_tui,
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step(
        "test",
        "Run codec, transport, lifecycle, stream, and API tests",
    );
    test_step.dependOn(&run_unit_tests.step);

    const example_module = b.createModule(.{
        .root_source_file = b.path("examples/watch.zig"),
        .target = target,
        .optimize = optimize,
    });
    example_module.addImport("hmux_tui", hmux_tui);
    const example = b.addExecutable(.{
        .name = "hmux-tui-watch",
        .root_module = example_module,
        .version = std.SemanticVersion.parse("1.0.0") catch unreachable,
    });
    b.installArtifact(example);

    const example_tests = b.addTest(.{
        .name = "hmux-tui-zig-consumer-test",
        .root_module = example_module,
    });
    const run_example_tests = b.addRunArtifact(example_tests);
    test_step.dependOn(&run_example_tests.step);
}
