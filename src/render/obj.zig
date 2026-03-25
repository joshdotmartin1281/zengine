const std = @import("std");
const Vec3 = @import("../math/vector.zig").Vector(3, f32);
const Vec2 = @import("../math/vector.zig").Vector(2, f32);

pub const FaceIndex = struct {
    v: u32,
    vt: ?u32,
    vn: ?u32,
};

pub const ObjMesh = struct {
    const Self = @This();

    positions: std.ArrayList(Vec3),
    texcoords: std.ArrayList(Vec2),
    normals: std.ArrayList(Vec3),
    indices: std.ArrayList(FaceIndex),

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .positions = std.ArrayList(Vec3).init(allocator),
            .texcoords = std.ArrayList(Vec2).init(allocator),
            .normals = std.ArrayList(Vec3).init(allocator),
            .indices = std.ArrayList(FaceIndex).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.positions.deinit();
        self.texcoords.deinit();
        self.normals.deinit();
        self.indices.deinit();
    }

    pub fn parseObj(self: *Self, allocator: std.mem.Allocator, path: []const u8) !void {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const source = try file.readToEndAlloc(allocator, 1024 * 1024 * 64); // 64MB max
        defer allocator.free(source);

        var lines = std.mem.splitScalar(u8, source, '\n');
        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
            if (trimmed.len == 0 or trimmed[0] == '#') continue;

            if (std.mem.startsWith(u8, trimmed, "vt ")) {
                const uv = try parseVec2(trimmed[3..]);
                try self.texcoords.append(uv);
            } else if (std.mem.startsWith(u8, trimmed, "vn ")) {
                const n = try parseVec3(trimmed[3..]);
                try self.normals.append(n);
            } else if (std.mem.startsWith(u8, trimmed, "v ")) {
                const pos = try parseVec3(trimmed[2..]);
                try self.positions.append(pos);
            } else if (std.mem.startsWith(u8, trimmed, "f ")) {
                try parseFace(self, trimmed[2..]);
            }
        }
    }

    fn parseVec3(s: []const u8) !Vec3 {
        var it = std.mem.tokenizeScalar(u8, s, ' ');
        const x = try std.fmt.parseFloat(f32, it.next() orelse return error.MissingComponent);
        const y = try std.fmt.parseFloat(f32, it.next() orelse return error.MissingComponent);
        const z = try std.fmt.parseFloat(f32, it.next() orelse return error.MissingComponent);
        return Vec3{ .data = .{ x, y, z } };
    }

    fn parseVec2(s: []const u8) !Vec2 {
        var it = std.mem.tokenizeScalar(u8, s, ' ');
        const x = try std.fmt.parseFloat(f32, it.next() orelse return error.MissingComponent);
        const y = try std.fmt.parseFloat(f32, it.next() orelse return error.MissingComponent);
        return Vec2{ .data = .{ x, y } };
    }

    fn parseFaceIndex(token: []const u8) !FaceIndex {
        var it = std.mem.splitScalar(u8, token, '/');
        const v = try std.fmt.parseInt(u32, it.next() orelse return error.MissingIndex, 10);
        const vt_str = it.next();
        const vn_str = it.next();

        const vt: ?u32 = if (vt_str != null and vt_str.?.len > 0)
            try std.fmt.parseInt(u32, vt_str.?, 10)
        else
            null;

        const vn: ?u32 = if (vn_str != null and vn_str.?.len > 0)
            try std.fmt.parseInt(u32, vn_str.?, 10)
        else
            null;

        return FaceIndex{
            .v = v - 1,
            .vt = if (vt) |t| t - 1 else null,
            .vn = if (vn) |n| n - 1 else null,
        };
    }

    fn parseFace(self: *Self, s: []const u8) !void {
        var tokens = std.mem.tokenizeScalar(u8, s, ' ');

        var verts: [4]FaceIndex = undefined;
        var count: usize = 0;

        while (tokens.next()) |token| {
            if (count >= 4) return error.UnsupportedPolygon;
            verts[count] = try parseFaceIndex(token);
            count += 1;
        }

        switch (count) {
            3 => {
                try self.indices.append(verts[0]);
                try self.indices.append(verts[1]);
                try self.indices.append(verts[2]);
            },
            4 => {
                try self.indices.append(verts[0]);
                try self.indices.append(verts[1]);
                try self.indices.append(verts[2]);

                try self.indices.append(verts[0]);
                try self.indices.append(verts[2]);
                try self.indices.append(verts[3]);
            },
            else => return error.UnsupportedPolygon,
        }
    }
};
