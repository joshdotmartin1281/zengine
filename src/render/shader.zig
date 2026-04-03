const std = @import("std");
const c = @import("../platform/window.zig").c;

pub const Shader = struct {
    id: c.GLuint,

    pub fn init(vert_src: [*c]const u8, frag_src: [*c]const u8) !Shader {
        const vert = c.glCreateShader(c.GL_VERTEX_SHADER);
        c.glShaderSource(vert, 1, &vert_src, null);
        c.glCompileShader(vert);
        try checkCompile(vert, "VERTEX");

        const frag = c.glCreateShader(c.GL_FRAGMENT_SHADER);
        c.glShaderSource(frag, 1, &frag_src, null);
        c.glCompileShader(frag);
        try checkCompile(frag, "FRAGMENT");

        const id = c.glCreateProgram();
        c.glAttachShader(id, vert);
        c.glAttachShader(id, frag);
        c.glLinkProgram(id);
        try checkLink(id);

        c.glDeleteShader(vert);
        c.glDeleteShader(frag);

        return .{ .id = id };
    }

    pub fn deinit(self: Shader) void {
        c.glDeleteProgram(self.id);
    }

    pub fn bind(self: Shader) void {
        c.glUseProgram(self.id);
    }

    pub fn setMat4(self: Shader, name: [*c]const u8, mat: anytype) void {
        const loc = c.glGetUniformLocation(self.id, name);
        c.glUniformMatrix4fv(loc, 1, c.GL_FALSE, &mat.cols[0].data[0]);
    }

    pub fn setInt(self: Shader, name: [*c]const u8, value: c_int) void {
        const loc = c.glGetUniformLocation(self.id, name);
        c.glUniform1i(loc, value);
    } 

    fn checkCompile(shader: c.GLuint, kind: []const u8) !void {
        var success: c.GLint = 0;
        c.glGetShaderiv(shader, c.GL_COMPILE_STATUS, &success);
        if (success == 0) {
            var log: [512]u8 = undefined;
            c.glGetShaderInfoLog(shader, 512, null, &log);
            std.log.err("{s} shader error: {s}", .{ kind, log });
            return error.ShaderCompileFailed;
        }
    }

    fn checkLink(program: c.GLuint) !void {
        var success: c.GLint = 0;
        c.glGetProgramiv(program, c.GL_LINK_STATUS, &success);
        if (success == 0) {
            var log: [512]u8 = undefined;
            c.glGetProgramInfoLog(program, 512, null, &log);
            std.log.err("link error: {s}", .{log});
            return error.ShaderLinkFailed;
        }
    }
};
