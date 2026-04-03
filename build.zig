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
    const target = compile.root_module.resolved_target.?;
    const optimize = compile.root_module.optimize.?;

    compile.linkLibC();

    compile.addIncludePath(b.path("deps/stb"));
    compile.addCSourceFile(.{
        .file = b.path("deps/stb/stb_image.c"),
        .flags = &[_][] const u8{"-std=c99"},
    });

    compile.addIncludePath(b.path("deps/glad/include"));
    compile.addCSourceFile(.{
        .file = b.path("deps/glad/src/glad.c"),
        .flags = &[_][]const u8{"-std=c99"},
    });

    const glfw = addGLFW(b, target, optimize);

    if (target.result.os.tag == .windows) {
        glfw.linkSystemLibrary("gdi32");
        glfw.linkSystemLibrary("user32");
        glfw.linkSystemLibrary("shell32");
        glfw.linkSystemLibrary("opengl32");
        glfw.linkSystemLibrary("dwmapi");
    }

    compile.linkLibrary(glfw);
    compile.addIncludePath(b.path("deps/glfw-3.4/include"));

    switch (target.result.os.tag) {
        .linux => {
            compile.linkSystemLibrary("GL");
            compile.linkSystemLibrary("X11");
            compile.linkSystemLibrary("Xi");
            compile.linkSystemLibrary("Xcursor");
            compile.linkSystemLibrary("Xrandr");
            compile.linkSystemLibrary("m");
            compile.linkSystemLibrary("dl");
            compile.linkSystemLibrary("pthread");
        },
        .windows => {
            compile.linkSystemLibrary("opengl32");
            compile.linkSystemLibrary("gdi32");
            compile.linkSystemLibrary("user32");
            compile.linkSystemLibrary("shell32");
            compile.linkSystemLibrary("dwmapi");
        },
        else => {},
    }
}

fn addGLFW(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const glfw = b.addStaticLibrary(.{
        .name = "glfw",
        .target = target,
        .optimize = optimize,
    });

    glfw.linkLibC();
    glfw.addIncludePath(b.path("deps/glfw-3.4/include"));

    const common_sources = [_][]const u8{
        "context.c",
        "init.c",
        "input.c",
        "monitor.c",
        "platform.c",
        "vulkan.c",
        "window.c",
        "egl_context.c",
        "osmesa_context.c",
        "null_init.c",
        "null_monitor.c",
        "null_window.c",
        "null_joystick.c",
    };

    glfw.addCSourceFiles(.{
        .root = b.path("deps/glfw-3.4/src"),
        .files = &common_sources,
    });

    switch (target.result.os.tag) {
        .windows => {
            glfw.root_module.addCMacro("_GLFW_WIN32", "1");
            glfw.root_module.addCMacro("_GLFW_WGL", "1");
            glfw.addCSourceFiles(.{
                .root = b.path("deps/glfw-3.4/src"),
                .files = &[_][]const u8{
                    "win32_init.c",
                    "win32_joystick.c",
                    "win32_monitor.c",
                    "win32_time.c",
                    "win32_thread.c",
                    "win32_window.c",
                    "win32_module.c",
                    "wgl_context.c",
                },
            });
        },
        .linux => {
            glfw.root_module.addCMacro("_GLFW_X11", "1");
            glfw.addCSourceFiles(.{
                .root = b.path("deps/glfw-3.4/src"),
                .files = &[_][]const u8{
                    "x11_init.c",
                    "x11_monitor.c",
                    "x11_window.c",
                    "xkb_unicode.c",
                    "posix_time.c",
                    "posix_thread.c",
                    "posix_module.c",
                    "posix_poll.c",
                    "linux_joystick.c",
                    "glx_context.c",
                },
            });
        },
        else => {},
    }

    return glfw;
}
