const std = @import("std");

pub const c = @cImport({
    @cInclude("glad/glad.h");
    @cInclude("GLFW/glfw3.h");
});

pub const WindowConfig = struct {
    width: u32,
    height: u32,
    fullscreen: bool,
    refresh_rate: u32,
    title: [:0]const u8,
    vsync: bool,
};

pub const Window = struct {
    handle: *c.GLFWwindow,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, config: WindowConfig) !Window {
        if (c.glfwInit() == c.GLFW_FALSE) return WindowError.GlfWInitFailed;

        c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
        c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 3);
        c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);

        c.glfwWindowHint(c.GLFW_REFRESH_RATE, @intCast(config.refresh_rate));

        var monitor: ?*c.GLFWmonitor = null;

        if (config.fullscreen) {
            monitor = c.glfwGetPrimaryMonitor();
        }

        const handle = c.glfwCreateWindow(@intCast(config.width),
            @intCast(config.height), 
            config.title, 
            monitor, 
            null
        ) orelse {
            c.glfwTerminate();
            return WindowError.WindowCreationFailed;
        };

        c.glfwMakeContextCurrent(handle);
        c.glfwSwapInterval(if (config.vsync) 1 else 0);

        if (c.gladLoadGLLoader(@ptrCast(&c.glfwGetProcAddress)) == 0) {
            c.glfwDestroyWindow(handle);
            c.glfwTerminate();
            return WindowError.GladLoadFailed;
        }

        return Window{ .handle = handle, .allocator = allocator };
    }

    pub fn deinit(self: *Window) void {
        c.glfwDestroyWindow(self.handle);
        c.glfwTerminate();
    }

    pub fn shouldClose(self: *const Window) bool {
        return c.glfwWindowShouldClose(self.handle) != 0;
    }

    pub fn pollEvents(_: *const Window) void {
        c.glfwPollEvents();
    }

    pub fn swapBuffers(self: *Window) void {
        c.glfwSwapBuffers(self.handle);
    }
};

pub const WindowError = error{
    GlfWInitFailed,
    WindowCreationFailed,
    GladLoadFailed,
};
