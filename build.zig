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

    // Comprehensive unit tests
    const comprehensive_test_module = b.createModule(.{
        .root_source_file = b.path("test/comprehensive_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    comprehensive_test_module.addImport("yaml", yaml_module);

    const comprehensive_tests = b.addTest(.{
        .root_module = comprehensive_test_module,
    });
    test_step.dependOn(&b.addRunArtifact(comprehensive_tests).step);

    // YAML Test Suite spec tests
    const enable_spec_tests = b.option(bool, "enable-spec-tests", "Enable YAML Test Suite") orelse false;
    if (enable_spec_tests) {
        const SpecTest = @import("test/spec.zig");
        const spec_test = SpecTest.create(b);

        const spec_test_module = b.createModule(.{
            .root_source_file = spec_test.path(),
            .target = target,
            .optimize = optimize,
        });
        spec_test_module.addImport("yaml", yaml_module);

        const spec_tests = b.addTest(.{
            .root_module = spec_test_module,
        });
        test_step.dependOn(&b.addRunArtifact(spec_tests).step);
    }
}
