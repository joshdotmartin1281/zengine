const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const dev_exe = createExe(b, target, "dev-app", .Debug);
    const run_dev = b.addRunArtifact(dev_exe);
    const dev_step = b.step("dev", "Run debug app");
    dev_step.dependOn(&run_dev.step);

    const rel_exe = createExe(b, target, "app", .ReleaseFast);
    const install_rel = b.addInstallArtifact(rel_exe, .{});
    const release_step = b.step("release", "Build release binary");
    release_step.dependOn(&install_rel.step);

    const test_step = b.step("test", "Run standard tests");
    const standard_test = createTest(b, target, .Debug);
    test_step.dependOn(&b.addRunArtifact(standard_test).step);
}

fn createExe(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    name: []const u8,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .code_model = .small,
        }),
    });

    setupModule(exe);
    return exe;
}

fn createTest(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const tester = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    setupModule(tester);
    return tester;
}

fn setupModule(compile: *std.Build.Step.Compile) void {
    const b = compile.step.owner;

    compile.linkLibC();
    compile.addIncludePath(b.path("deps/glad/include"));
    compile.addCSourceFile(.{
        .file = b.path("deps/glad/src/glad.c"),
        .flags = &[_][]const u8{"-std=c99"},
    });

    compile.linkSystemLibrary("glfw");

    const target = compile.root_module.resolved_target.?;
    switch (target.result.os.tag) {
        .linux => {
            compile.linkSystemLibrary("GL");
            compile.linkSystemLibrary("X11");
        },
        .windows => {
            compile.linkSystemLibrary("opengl32");
            compile.linkSystemLibrary("gdi32");
        },
        .macos => {
            compile.linkFramework("OpenGL");
            compile.linkFramework("Cocoa");
            compile.linkFramework("IOKit");
            compile.linkFramework("CoreVideo");
        },
        else => {},
    }
}

