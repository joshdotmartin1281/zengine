const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const BuildOption = struct {
        step_name: []const u8,
        description: []const u8,
        optimize: std.builtin.OptimizeMode,
        is_test: bool = false,
    };

    const options = [_]BuildOption{
        .{ .step_name = "dev",     .description = "Benchmarking (.ReleaseSafe)", .optimize = .ReleaseSafe },
        .{ .step_name = "release", .description = "Production (.ReleaseFast)",   .optimize = .ReleaseFast },
        .{ .step_name = "test",    .description = "Exhaustive Testing (.Debug)", .optimize = .Debug, .is_test = true },
    };

    for (options) |opt| {
        const zgl_dep = b.dependency("zgl", .{
            .target = target,
            .optimize = opt.optimize,
        });

        const run_step = b.step(opt.step_name, opt.description);

        if (opt.is_test) {
            const unit_tests = b.addTest(.{
                .root_module = b.createModule(.{
                    .root_source_file = b.path("src/main.zig"),
                    .target = target,
                    .optimize = opt.optimize,
                }),
            });
            setupModule(unit_tests, zgl_dep, target);
            run_step.dependOn(&b.addRunArtifact(unit_tests).step);
        } else {
            const exe = b.addExecutable(.{
                .name = if (std.mem.eql(u8, opt.step_name, "dev")) "zengine-dev" else "zengine",
                .root_module = b.createModule(.{
                    .root_source_file = b.path("src/main.zig"),
                    .target = target,
                    .optimize = opt.optimize,
                }),
            });
            setupModule(exe, zgl_dep, target);
            b.installArtifact(exe); 
            run_step.dependOn(&b.addRunArtifact(exe).step);
        }
    }
}

fn setupModule(compile: *std.Build.Step.Compile, zgl_dep: *std.Build.Dependency, target: std.Build.ResolvedTarget) void {
    compile.root_module.addImport("zgl", zgl_dep.module("zgl"));
    compile.linkSystemLibrary("glfw");

    const os_tag = target.result.os.tag;
    switch (os_tag) {
        .linux => compile.linkSystemLibrary("GL"),
        .windows => compile.linkSystemLibrary("opengl32"),
        .macos => {
            compile.linkFramework("OpenGL");
            compile.linkFramework("Cocoa");
        },
        else => {},
    }
}
