const std = @import("std");
pub const c = @cImport({
    @cInclude("../graphics/glad/glad.h");
    @cInclude("GLFW/glfw3.h");
});

pub const WindowError = error{
    GlfWInitFailed,
    WindowCreationFailed,
    GladLoadFailed,
};

pub const WindowBuilder = struct {
    handle: ?*c.GLFWwindow = null,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, width: i32, height: i32, title: [:0]const u8) !@This() {
        if (c.glfwInit() == c.GLFW_FALSE) {
            std.log.err("Failed to initialize GLFW", .{});
            return WindowError.GlfWInitFailed;
        }

        c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
        c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 3);
        c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);
        c.glfwWindowHint(c.GLFW_OPENGL_FORWARD_COMPAT, c.GL_TRUE);

        //add json support for this later in a seperate function.
        const handle = c.glfwCreateWindow(width, height, title, null, null) orelse {
            c.glfwTerminate();
            return WindowError.WindowCreationFailed;
        };

        c.glfwMakeContextCurrent(handle);

        const result = c.gladLoadGLLoader(struct {
            fn load_proc(name: [*c]const u8) callconv(.C) ?*anyopaque {
                const raw_fn_ptr = c.glfwGetProcAddress(name);
                return if (raw_fn_ptr) |ptr|
                    @constCast(@as(?*const anyopaque, ptr))
                else
                    null;
            }
        }.load_proc);

        if (result == 0) {
            c.glfwDestroyWindow(handle);
            c.glfwTerminate();
            return WindowError.GladLoadFailed;
        }

        const vendor = c.glGetString(c.GL_VENDOR);
        const renderer = c.glGetString(c.GL_RENDERER);
        const version = c.glGetString(c.GL_VERSION);

        std.debug.print("OpenGL Vendor: {s}\n", .{vendor});
        std.debug.print("OpenGL Renderer: {s}\n", .{renderer});
        std.debug.print("OpenGL Version: {s}\n", .{version});

        return .{ .handle = handle, .allocator = allocator };
    }

    pub fn deinit(self: *WindowBuilder) void {
        if (self.handle) |win| {
            c.glfwDestroyWindow(win);
            self.handle = null;
        }
        c.glfwTerminate();
    }
    //pub fn set_cursor_mode(self: *WindowBuilder, locked: bool) {}

    //pub fn get_aspect_ratio(self: *const WindowBuilder) f32 {}

    pub fn shouldClose(self: @This()) bool {
        return c.glfwWindowShouldClose(self.handle) == c.GL_TRUE;
    }

    pub fn update(self: @This()) void {
        c.glfwSwapBuffers(self.handle);
        c.glfwPollEvents();
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
};
