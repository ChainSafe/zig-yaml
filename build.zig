const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const enable_logging = b.option(bool, "log", "Whether to enable logging") orelse false;
    _ = enable_logging;
    const yaml_module = b.addModule("yaml", .{
        .root_source_file = b.path("src/lib.zig"),
    });

    const yaml_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/lib.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&b.addRunArtifact(yaml_tests).step);

    const e2e_test_module = b.createModule(.{
        .root_source_file = b.path("test/test.zig"),
        .target = target,
        .optimize = optimize,
    });
    e2e_test_module.addImport("yaml", yaml_module);

    const e2e_tests = b.addTest(.{
        .root_module = e2e_test_module,
    });
    test_step.dependOn(&b.addRunArtifact(e2e_tests).step);

    // TODO: spec tests need full std.fs → std.Io.Dir migration in test/spec.zig
    // const enable_spec_tests = b.option(bool, "enable-spec-tests", "Enable YAML Test Suite") orelse false;
}
