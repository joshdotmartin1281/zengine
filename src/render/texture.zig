const std = @import("std");
const c = @import("../platform/window.zig").c;

pub const Texture = struct {
    id: c.GLuint,

    pub fn load(path: [*c]const u8) !Texture {
        var width: c_int = 0;
        var height: c_int = 0;
        var channels: c_int = 0;

        c.stbi_set_flip_vertically_on_load(1);
        const data = c.stbi_load(path, &width, &height, &channels, 4) orelse {
            std.log.err("Failed to load texture: {s}", .{path});
            return error.TextureLoadFailed;
        };
        defer c.stbi_image_free(data);

        var id: c.GLuint = 0;
        c.glGenTextures(1, &id);
        c.glBindTexture(c.GL_TEXTURE_2D, id);

        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_REPEAT);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_REPEAT);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR_MIPMAP_LINEAR);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);

        c.glTexImage2D(
            c.GL_TEXTURE_2D,
            0,
            c.GL_RGBA,
            width,
            height,
            0,
            c.GL_RGBA,
            c.GL_UNSIGNED_BYTE,
            data,
        );
        c.glGenerateMipmap(c.GL_TEXTURE_2D);

        c.glBindTexture(c.GL_TEXTURE_2D, 0);

        return .{ .id = id };
    }

    pub fn bind(self: Texture, slot: c_uint) void {
        c.glActiveTexture(@intCast(c.GL_TEXTURE0 + @as(c_int, @intCast(slot))));
        c.glBindTexture(c.GL_TEXTURE_2D, self.id);
    }

    pub fn deinit(self: *Texture) void {
        c.glDeleteTextures(1, &self.id);
    }
};
