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
    texture_path: ?[]u8,

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .positions = std.ArrayList(Vec3).init(allocator),
            .texcoords = std.ArrayList(Vec2).init(allocator),
            .normals = std.ArrayList(Vec3).init(allocator),
            .indices = std.ArrayList(FaceIndex).init(allocator),
            .texture_path = null,
        };
    }

    pub fn deinit(self: *Self) void {
        const allocator = self.positions.allocator;
        if (self.texture_path) |p| allocator.free(p);
        self.positions.deinit();
        self.texcoords.deinit();
        self.normals.deinit();
        self.indices.deinit();
    }

    pub fn parseObj(self: *Self, path: []const u8) !void {
        const allocator = self.positions.allocator;
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const source = try file.readToEndAlloc(allocator, 1024 * 1024 * 64);
        defer allocator.free(source);

        const dir = std.fs.path.dirname(path) orelse ".";

        var lines = std.mem.splitScalar(u8, source, '\n');
        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
            if (trimmed.len == 0 or trimmed[0] == '#') continue;

            if (std.mem.startsWith(u8, trimmed, "mtllib ")) {
                const mtl_name = std.mem.trim(u8, trimmed[7..], &std.ascii.whitespace);
                const mtl_path = try std.fs.path.join(allocator, &.{ dir, mtl_name });
                defer allocator.free(mtl_path);
                try self.parseMtl(mtl_path, dir);
            } else if (std.mem.startsWith(u8, trimmed, "vt ")) {
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

    fn parseMtl(self: *Self, path: []const u8, dir: []const u8) !void {
        const allocator = self.positions.allocator;
        const file = std.fs.cwd().openFile(path, .{}) catch return;
        defer file.close();

        const source = try file.readToEndAlloc(allocator, 1024 * 1024);
        defer allocator.free(source);

        var lines = std.mem.splitScalar(u8, source, '\n');
        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
            if (trimmed.len == 0 or trimmed[0] == '#') continue;

            if (std.mem.startsWith(u8, trimmed, "map_Kd ")) {
                const raw = std.mem.trim(u8, trimmed[7..], &std.ascii.whitespace);
                const filename = std.fs.path.basename(raw);
                const full = try std.fs.path.join(allocator, &.{ dir, filename });
                if (self.texture_path) |old| allocator.free(old);
                self.texture_path = full;
            }
        }
    }

    fn parseVec3(s: []const u8) !Vec3 {
        var it = std.mem.tokenizeScalar(u8, s, ' ');
        const x = try std.fmt.parseFloat(f32, it.next() orelse return error.MissingComponent);
        const y = try std.fmt.parseFloat(f32, it.next() orelse return error.MissingComponent);
        const z = try std.fmt.parseFloat(f32, it.next() orelse return error.MissingComponent);
        return Vec3.init(.{ x, y, z });
    }

    fn parseVec2(s: []const u8) !Vec2 {
        var it = std.mem.tokenizeScalar(u8, s, ' ');
        const x = try std.fmt.parseFloat(f32, it.next() orelse return error.MissingComponent);
        const y = try std.fmt.parseFloat(f32, it.next() orelse return error.MissingComponent);
        return Vec2.init(.{ x, y });
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

    pub fn debugPrint(self: *const Self) void {
        std.debug.print("texture_path: {?s}\n", .{self.texture_path});
        std.debug.print("positions ({d}):\n", .{self.positions.items.len});
        for (self.positions.items) |p| {
            std.debug.print("  ({d:.3}, {d:.3}, {d:.3})\n", .{ p.data[0], p.data[1], p.data[2] });
        }
        std.debug.print("texcoords ({d}):\n", .{self.texcoords.items.len});
        for (self.texcoords.items) |uv| {
            std.debug.print("  ({d:.3}, {d:.3})\n", .{ uv.data[0], uv.data[1] });
        }
        std.debug.print("normals ({d}):\n", .{self.normals.items.len});
        for (self.normals.items) |n| {
            std.debug.print("  ({d:.3}, {d:.3}, {d:.3})\n", .{ n.data[0], n.data[1], n.data[2] });
        }
        std.debug.print("indices ({d}):\n", .{self.indices.items.len});
        for (self.indices.items) |fi| {
            std.debug.print("  v={d}", .{fi.v});
            if (fi.vt) |vt| std.debug.print(" vt={d}", .{vt});
            if (fi.vn) |vn| std.debug.print(" vn={d}", .{vn});
            std.debug.print("\n", .{});
        }
    }
};
