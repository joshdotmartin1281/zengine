const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zengine",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.linkLibC();

    exe.addIncludePath(b.path("src/graphics/glad"));
    exe.addIncludePath(b.path("src/KHR"));

    exe.addCSourceFiles(.{
        .files = &[_][]const u8{
            "src/graphics/glad.c",
        },
    });

    exe.linkSystemLibrary("glfw");

    switch (builtin.os.tag) {
        .linux => {
            exe.linkSystemLibrary("GL");
        },
        .windows => {
            exe.linkSystemLibrary("opengl32");
        },
        .macos => {
            exe.linkFramework("OpenGL");
            exe.linkFramework("Cocoa");
        },
        else => {},
    }

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_cmd.step);

    const tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    tests.linkLibC();
    tests.addIncludePath(b.path("src/graphics/glad"));
    tests.addIncludePath(b.path("src/KHR"));
    tests.addCSourceFiles(.{
        .files = &[_][]const u8{
            "src/graphics/glad.c",
        },
    });
    tests.linkSystemLibrary("glfw");

    switch (builtin.os.tag) {
        .linux => {
            tests.linkSystemLibrary("GL");
        },
        .windows => {
            tests.linkSystemLibrary("opengl32");
        },
        .macos => {
            tests.linkFramework("OpenGL");
            tests.linkFramework("Cocoa");
        },
        else => {},
    }

    const test_run_cmd = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&test_run_cmd.step);
}
