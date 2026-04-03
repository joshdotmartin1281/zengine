const std = @import("std");
pub const c = @cImport({
    @cInclude("glad/glad.h");
    @cInclude("GLFW/glfw3.h");
    @cInclude("stb_image.h");
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
        c.glfwWindowHint(c.GLFW_COCOA_RETINA_FRAMEBUFFER, c.GLFW_TRUE);
        c.glfwWindowHint(c.GLFW_REFRESH_RATE, @intCast(config.refresh_rate));

        var monitor: ?*c.GLFWmonitor = null;
        if (config.fullscreen) {
            monitor = c.glfwGetPrimaryMonitor();
        }

        const handle = c.glfwCreateWindow(
            @intCast(config.width),
            @intCast(config.height),
            config.title,
            monitor,
            null,
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

        c.glViewport(0, 0, @intCast(config.width), @intCast(config.height));

        _ = c.glfwSetFramebufferSizeCallback(handle, glfw_framebuffer_size_callback);

        return Window{ .handle = handle, .allocator = allocator };
    }

    pub fn deinit(self: *Window) void {
        c.glfwDestroyWindow(self.handle);
        c.glfwTerminate();
    }

    pub fn setUserPointer(self: *Window, ptr: *anyopaque) void {
        _ = c.glfwSetWindowUserPointer(self.handle, ptr);
    }

    pub fn registerCallbacks(self: *Window, comptime T: type) void {
        _ = c.glfwSetKeyCallback(self.handle, T.glfw_key_callback);
        _ = c.glfwSetMouseButtonCallback(self.handle, T.glfw_mouse_callback);
        _ = c.glfwSetCursorPosCallback(self.handle, T.glfw_cursor_position_callback);
        _ = c.glfwSetScrollCallback(self.handle, T.glfw_scroll_callback);
    }

    pub fn aspectRatio(self: *const Window) f32 {
        var w: c_int = 0;
        var h: c_int = 0;
        c.glfwGetFramebufferSize(self.handle, &w, &h);
        return @as(f32, @floatFromInt(w)) / @as(f32, @floatFromInt(h));
    }

    pub fn lockCursor(self: *Window) void {
        _ = c.glfwSetInputMode(self.handle, c.GLFW_CURSOR, c.GLFW_CURSOR_DISABLED);
    }

    pub fn unlockCursor(self: *Window) void {
        _ = c.glfwSetInputMode(self.handle, c.GLFW_CURSOR, c.GLFW_CURSOR_NORMAL);
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

    fn glfw_framebuffer_size_callback(
        _: ?*c.GLFWwindow,
        width: c_int,
        height: c_int,
    ) callconv(.c) void {
        c.glViewport(0, 0, width, height);
    }
};

pub const WindowError = error{
    GlfWInitFailed,
    WindowCreationFailed,
    GladLoadFailed,
};
