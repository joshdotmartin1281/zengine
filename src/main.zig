// src/main.zig
const std = @import("std");
const window_builder = @import("window/window_builder.zig");
const Shader = @import("graphics/shader.zig").Shader; // Import the Shader struct
const InputManager = @import("input/input_manager.zig").InputManager;
const settings = @import("settings.zig");
const c = window_builder.c;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const parsed_settings = try settings.loadSettings(allocator, "src/settings.json");
    defer parsed_settings.deinit();
    const app_settings = parsed_settings.value;

    var wb = try window_builder.WindowBuilder.init(allocator, 800, 600, "Zengine");
    defer wb.deinit();

    // --- Vertices for a triangle ---
    const vertices = [_]f32{
        -0.5, -0.5, 0.0, // Bottom-left
        0.5, -0.5, 0.0, // Bottom-right
        0.0, 0.5, 0.0, // Top
    };

    var input_manager = try InputManager.init(allocator, app_settings.input);
    defer input_manager.deinit();
    c.glfwSetWindowUserPointer(wb.handle, @as(*anyopaque, &input_manager));
    _ = c.glfwSetKeyCallback(wb.handle, InputManager.glfw_key_callback);
    _ = c.glfwSetMouseButtonCallback(wb.handle, InputManager.glfw_mouse_callback);
    _ = c.glfwSetCursorPosCallback(wb.handle, InputManager.glfw_cursor_position_callback);
    _ = c.glfwSetScrollCallback(wb.handle, @ptrCast(&InputManager.glfw_scroll_callback));

    // --- Shader Initialization ---
    // Paths are relative to your build.zig's root_source_file or working directory when running 'zig run'
    // If you're building from the project root, "src/shaders/simple.vert" is correct.
    var my_shader = try Shader.init("src/shaders/simple.vert", "src/shaders/simple.frag");
    defer my_shader.deinit();

    // --- VBO and VAO setup (same as before) ---
    var VBO: c.GLuint = 0;
    var VAO: c.GLuint = 0;

    c.glGenVertexArrays(1, &VAO);
    c.glGenBuffers(1, &VBO);

    c.glBindVertexArray(VAO);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, VBO);
    c.glBufferData(c.GL_ARRAY_BUFFER, vertices.len * @sizeOf(f32), @ptrCast(&vertices[0]), c.GL_STATIC_DRAW);
    c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, 3 * @sizeOf(f32), @ptrFromInt(0));
    c.glEnableVertexAttribArray(0);

    c.glBindBuffer(c.GL_ARRAY_BUFFER, 0);
    c.glBindVertexArray(0);

    // --- Main Render Loop ---
    while (!wb.shouldClose()) {
        input_manager.update();
        wb.pollEvents();

        if (input_manager.is_action_pressed(.M1)) {
            std.debug.print("M1 action just pressed\n", .{});
        }

        if (input_manager.is_action_released(.Jump)) {
            std.debug.print("Jump action just released\n", .{});
        }

        if (input_manager.is_action_pressed(.Forward)) {
            std.debug.print("Forward action just pressed\n", .{});
        }

        if (input_manager.is_action_held(.M1)) {
            std.debug.print("M1 action held\n", .{});
        }

        if (input_manager.is_action_released(.Forward)) {
            std.debug.print("Forward action just released\n", .{});
        }

        //std.debug.print("Mouse moved x: {d}\n", .{input_manager.get_mouse_x()});
        //std.debug.print("Mouse moved y: {d}\n", .{input_manager.get_mouse_y()});
        if (input_manager.get_scroll_offset().x != input_manager.get_scroll_offset().y) {
            std.debug.print("Scroll wheel delta: {any}\n", .{input_manager.get_scroll_offset()});
        }

        c.glClearColor(0.2, 0.3, 0.3, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT);

        my_shader.use(); // Use the shader program via the Shader struct
        c.glBindVertexArray(VAO);
        c.glDrawArrays(c.GL_TRIANGLES, 0, 3);
        c.glBindVertexArray(0);

        wb.swapBuffers();
    }

    // --- Cleanup OpenGL objects ---
    c.glDeleteVertexArrays(1, &VAO);
    c.glDeleteBuffers(1, &VBO);
}
