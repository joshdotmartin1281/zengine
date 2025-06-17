// src/main.zig
const std = @import("std");
const window_builder = @import("window/window_builder.zig");
const Shader = @import("graphics/shader.zig").Shader; // Import the Shader struct
const c = window_builder.c;

pub fn main() !void {
    var wb = window_builder.WindowBuilder{};
    try wb.init(800, 600, "Zig OpenGL Window");
    defer wb.destroy();

    // --- Vertices for a triangle ---
    const vertices = [_]f32{
        -0.5, -0.5, 0.0, // Bottom-left
        0.5, -0.5, 0.0, // Bottom-right
        0.0, 0.5, 0.0, // Top
    };

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
        wb.pollEvents();

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
