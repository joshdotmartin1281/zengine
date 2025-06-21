// src/shader.zig
const std = @import("std");
const c = @import("../window/window_builder.zig").c; // Import the public 'c' from window_builder

pub const Shader = struct {
    id: c.GLuint,
    //allocator: std.mem.Allocator,

    pub fn init(vertex_path: []const u8, fragment_path: []const u8) !Shader {
        var vertex_source: []u8 = &.{}; // Initialize as empty slice
        var fragment_source: []u8 = &.{}; // Initialize as empty slice
        const allocator = std.heap.page_allocator;

        defer {
            // Only free if the slice actually points to allocated memory and has a length
            if (vertex_source.len > 0) allocator.free(vertex_source);
            if (fragment_source.len > 0) allocator.free(fragment_source);
        }

        // Read vertex shader source
        var vert_file = try std.fs.cwd().openFile(vertex_path, .{});
        defer vert_file.close();
        vertex_source = try vert_file.readToEndAlloc(allocator, 1024 * 4); // Max 4KB for shaders, adjust as needed

        // Read fragment shader source
        var frag_file = try std.fs.cwd().openFile(fragment_path, .{});
        defer frag_file.close();
        fragment_source = try frag_file.readToEndAlloc(allocator, 1024 * 4);

        const vertex_shader = try compileShader(c.GL_VERTEX_SHADER, vertex_source);
        const fragment_shader = try compileShader(c.GL_FRAGMENT_SHADER, fragment_source);

        const program_id = try linkProgram(vertex_shader, fragment_shader);

        return Shader{ .id = program_id };
    }

    pub fn use(self: Shader) void {
        c.glUseProgram(self.id);
    }

    pub fn setInt(self: Shader, name: []const u8, value: i32) void {
        const location = c.glGetUniformLocation(self.id, name.ptr);
        c.glUniform1i(location, value);
    }

    pub fn setFloat(self: Shader, name: []const u8, value: f32) void {
        const location = c.glGetUniformLocation(self.id, name.ptr);
        c.glUniform1f(location, value);
    }
    // ... add more setters for vec2, vec3, mat4 etc.

    pub fn deinit(self: Shader) void {
        c.glDeleteProgram(self.id);
    }

    // --- Helper functions (could be private or in an anonymous struct) ---
    fn compileShader(shader_type: c.GLenum, source: []const u8) !c.GLuint {
        const shader = c.glCreateShader(shader_type);
        if (shader == 0) {
            return error.ShaderCreationFailed;
        }
        var source_ptr = source.ptr;
        var source_len: c.GLint = @intCast(source.len);
        c.glShaderSource(shader, 1, &source_ptr, &source_len);
        c.glCompileShader(shader);

        var success: c.GLint = 0;
        var len: c.GLsizei = 0;
        c.glGetShaderiv(shader, c.GL_COMPILE_STATUS, &success);
        if (success == 0) {
            var info_log: [512]u8 = undefined;
            c.glGetShaderInfoLog(shader, info_log.len, &len, &info_log[0]);
            // THIS IS THE CRUCIAL CHANGE: Explicitly cast the array to a slice *first*,
            // then slice it with the converted length.
            const full_slice: []u8 = info_log[0..info_log.len];
            const error_message_slice = full_slice[0..@intCast(len)];
            std.debug.print("Shader compilation error:\n{s}\n", .{error_message_slice});
            c.glDeleteShader(shader);
            return error.ShaderCompilationFailed;
        }
        return shader;
    }

    fn linkProgram(vertex_shader: c.GLuint, fragment_shader: c.GLuint) !c.GLuint {
        const program = c.glCreateProgram();
        if (program == 0) {
            return error.ProgramCreationFailed;
        }
        c.glAttachShader(program, vertex_shader);
        c.glAttachShader(program, fragment_shader);
        c.glLinkProgram(program);

        var success: c.GLint = 0;
        var len: c.GLsizei = 0;
        c.glGetProgramiv(program, c.GL_LINK_STATUS, &success);
        if (success == 0) {
            var info_log: [512]u8 = undefined;
            c.glGetProgramInfoLog(program, info_log.len, &len, &info_log[0]);
            // Same crucial change here
            const full_slice: []u8 = info_log[0..info_log.len];
            const error_message_slice = full_slice[0..@intCast(len)];
            std.debug.print("Shader program linking error:\n{s}\n", .{error_message_slice});
            c.glDeleteProgram(program);
            return error.ProgramLinkingFailed;
        }
        c.glDetachShader(program, vertex_shader);
        c.glDetachShader(program, fragment_shader);
        c.glDeleteShader(vertex_shader);
        c.glDeleteShader(fragment_shader);
        return program;
    }
};

pub const ShaderError = error{
    ShaderCreationFailed,
    ShaderCompilationFailed,
    ProgramCreationFailed,
    ProgramLinkingFailed,
};
