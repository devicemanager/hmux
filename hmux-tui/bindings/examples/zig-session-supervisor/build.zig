const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const hmux_tui = b.addModule("hmux_tui", .{
        .root_source_file = b.path("../../zig/src/hmux.zig"),
        .target = target,
        .optimize = optimize,
    });

    const session_supervisor = b.addModule("session_supervisor", .{
        .root_source_file = b.path("src/supervisor.zig"),
        .target = target,
        .optimize = optimize,
    });
    session_supervisor.addImport("hmux_tui", hmux_tui);

    const executable_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    executable_module.addImport("hmux_tui", hmux_tui);
    executable_module.addImport("session_supervisor", session_supervisor);

    const executable = b.addExecutable(.{
        .name = "hmux-zig-session-supervisor",
        .root_module = executable_module,
        .version = std.SemanticVersion.parse("0.1.0") catch unreachable,
    });
    b.installArtifact(executable);

    const run_executable = b.addRunArtifact(executable);
    if (b.args) |args| run_executable.addArgs(args);
    const run_step = b.step("run", "Run the session supervisor");
    run_step.dependOn(&run_executable.step);

    const tests_module = b.createModule(.{
        .root_source_file = b.path("tests/fake_server.zig"),
        .target = target,
        .optimize = optimize,
    });
    tests_module.addImport("hmux_tui", hmux_tui);
    tests_module.addImport("session_supervisor", session_supervisor);
    const tests = b.addTest(.{
        .name = "hmux-zig-session-supervisor-tests",
        .root_module = tests_module,
    });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run deterministic fake resource server tests");
    test_step.dependOn(&run_tests.step);
}
