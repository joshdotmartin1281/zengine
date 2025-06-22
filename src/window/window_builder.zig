const std = @import("std");
pub const c = @cImport({
    @cInclude("../graphics/glad/glad.h");
    @cInclude("GLFW/glfw3.h");
});

pub const WindowBuilder = struct {
    handle: ?*c.GLFWwindow = null,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, width: i32, height: i32, title: [:0]const u8) !@This() {
        if (c.glfwInit() == c.GLFW_FALSE) {
            std.log.err("Failed to initialize GLFW", .{});
            return error.GLFWInitFailed;
        }

        c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
        c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 3);
        c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);
        c.glfwWindowHint(c.GLFW_OPENGL_FORWARD_COMPAT, c.GL_TRUE); // For macOS compatibility

        const handle = c.glfwCreateWindow(width, height, title, null, null) orelse {
            c.glfwTerminate();
            return error.WindowCreationFailed;
        };

        c.glfwMakeContextCurrent(handle);

        _ = c.gladLoadGLLoader(struct {
            fn load_proc(name: [*c]const u8) callconv(.C) ?*anyopaque {
                const raw_fn_ptr = c.glfwGetProcAddress(name);
                return if (raw_fn_ptr) |ptr|
                    @constCast(@as(?*const anyopaque, ptr))
                else
                    null;
            }
        }.load_proc);

        std.debug.print("OpenGL Vendor: {s}\n", .{c.glGetString(c.GL_VENDOR)});
        std.debug.print("OpenGL Renderer: {s}\n", .{c.glGetString(c.GL_RENDERER)});
        std.debug.print("OpenGL Version: {s}\n", .{c.glGetString(c.GL_VERSION)});

        return .{ .handle = handle, .allocator = allocator };
    }

    pub fn shouldClose(self: @This()) bool {
        return c.glfwWindowShouldClose(self.handle) == c.GL_TRUE;
    }

    pub fn update(self: @This()) void {
        c.glfwSwapBuffers(self.handle);
        c.glfwPollEvents();
    }

    pub fn deinit(self: @This()) void {
        c.glfwDestroyWindow(self.handle);
        c.glfwTerminate();
    }

    pub fn pollEvents(self: *WindowBuilder) void {
        _ = self;
        c.glfwPollEvents();
    }

    pub fn swapBuffers(self: *WindowBuilder) void {
        if (self.handle) |win| {
            c.glfwSwapBuffers(win);
        }
    }

    pub fn destroy(self: *WindowBuilder) void {
        if (self.handle) |win| {
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
