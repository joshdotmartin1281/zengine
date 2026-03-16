const c = @import("../window/window.zig").c;

pub const Triangle = struct {
    vao: c.GLuint,
    vbo: c.GLuint,

    pub fn init() Triangle {
        const vertices = [_]f32{
            0.0,  0.5,  0.0,
            -0.5, -0.5, 0.0,
            0.5,  -0.5, 0.0,
        };

        var vao: c.GLuint = 0;
        var vbo: c.GLuint = 0;

        c.glGenVertexArrays(1, &vao);
        c.glBindVertexArray(vao);

        c.glGenBuffers(1, &vbo);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
        c.glBufferData(c.GL_ARRAY_BUFFER, @sizeOf(@TypeOf(vertices)), &vertices, c.GL_STATIC_DRAW);

        c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, 3 * @sizeOf(f32), null);
        c.glEnableVertexAttribArray(0);

        c.glBindVertexArray(0);
        return .{ .vao = vao, .vbo = vbo };
    }

    pub fn deinit(self: Triangle) void {
        c.glDeleteVertexArrays(1, &self.vao);
        c.glDeleteBuffers(1, &self.vbo);
    }

    pub fn draw(self: Triangle) void {
        c.glBindVertexArray(self.vao);
        c.glDrawArrays(c.GL_TRIANGLES, 0, 3);
    }
};
