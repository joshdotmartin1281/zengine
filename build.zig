const std = @import("std");

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
    exe.linkSystemLibrary("GL"); // Linux
    // exe.linkSystemLibrary("opengl32"); // Windows
    // exe.linkFramework("OpenGL");       // macOS

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_cmd.step);
}
