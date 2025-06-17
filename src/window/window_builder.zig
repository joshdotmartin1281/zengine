const std = @import("std");
pub const c = @cImport({
    @cInclude("../graphics/glad/glad.h");
    @cInclude("GLFW/glfw3.h");
});

pub const WindowBuilder = struct {
    window: ?*c.GLFWwindow = null,

    pub fn init(self: *WindowBuilder, width: i32, height: i32, title: []const u8) !void {
        if (c.glfwInit() == 0) {
            return error.GlfwInitFailed; // Changed to error.GlfwInitFailed
        }

        c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
        c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 3);
        c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);
        // On macOS uncomment this line:
        // c.glfwWindowHint(c.GLFW_OPENGL_FORWARD_COMPAT, c.GL_TRUE);

        const win = c.glfwCreateWindow(width, height, title.ptr, null, null);
        if (win == null) {
            c.glfwTerminate();
            return error.WindowCreationFailed; // Changed to error.WindowCreationFailed
        }
        self.window = win;

        c.glfwMakeContextCurrent(win);

        if (c.gladLoadGL() == 0) {
            c.glfwDestroyWindow(win);
            c.glfwTerminate();
            return error.GladLoadFailed; // Changed to error.GladLoadFailed
        }

        // Enable vsync
        c.glfwSwapInterval(1);
    }

    pub fn shouldClose(self: *WindowBuilder) bool {
        if (self.window) |win| {
            return c.glfwWindowShouldClose(win) != 0;
        } else {
            return true; // or false, depending on desired behavior if no window
        }
    }

    pub fn pollEvents(self: *WindowBuilder) void {
        _ = self;
        c.glfwPollEvents();
    }

    pub fn swapBuffers(self: *WindowBuilder) void {
        if (self.window) |win| {
            c.glfwSwapBuffers(win);
        }
    }

    pub fn destroy(self: *WindowBuilder) void {
        if (self.window) |win| {
            c.glfwDestroyWindow(win);
            c.glfwTerminate();
            self.window = null;
        }
    }
};

pub const WindowError = error{
    GlfwInitFailed,
    WindowCreationFailed,
    GladLoadFailed,
};
