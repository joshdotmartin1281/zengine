const std = @import("std");
const Vec3 = @import("../math/vector.zig").Vector(3, f32);
const Vec2 = @import("../math/vector.zig").Vector(2, f32);
const ObjMesh = @import("obj.zig").ObjMesh;
const FaceIndex = @import("obj.zig").FaceIndex;

pub const Vertex = struct {
    position: Vec3,
    texcoord: Vec2,
    normal: Vec3,
};

pub const GpuMesh = struct {
    const Self = @This();

    vertices: std.ArrayList(Vertex),
    indices: std.ArrayList(u32),

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .vertices = std.ArrayList(Vertex).init(allocator),
            .indices = std.ArrayList(u32).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.vertices.deinit();
        self.indices.deinit();
    }
};

const FaceIndexContext = struct {
    pub fn hash(_: FaceIndexContext, k: FaceIndex) u64 {
        var h = std.hash.Wyhash.init(0);
        h.update(std.mem.asBytes(&k.v));
        h.update(std.mem.asBytes(&k.vt));
        h.update(std.mem.asBytes(&k.vn));
        return h.final();
    }

    pub fn eql(_: FaceIndexContext, a: FaceIndex, b: FaceIndex) bool {
        return a.v == b.v and a.vt == b.vt and a.vn == b.vn;
    }
};

pub fn deindex(mesh: *const ObjMesh, allocator: std.mem.Allocator) !GpuMesh {
    var result = GpuMesh.init(allocator);
    errdefer result.deinit();

    var seen = std.HashMap(
        FaceIndex,
        u32,
        FaceIndexContext,
        std.hash_map.default_max_load_percentage,
    ).init(allocator);
    defer seen.deinit();

    for (mesh.indices.items) |face| {
        const entry = try seen.getOrPut(face);
        if (!entry.found_existing) {
            entry.value_ptr.* = @intCast(result.vertices.items.len);

            const pos = mesh.positions.items[face.v];
            const uv = if (face.vt) |t| mesh.texcoords.items[t] else Vec2{ .data = .{ 0, 0 } };
            const nor = if (face.vn) |n| mesh.normals.items[n] else Vec3{ .data = .{ 0, 0, 0 } };

            try result.vertices.append(.{
                .position = pos,
                .texcoord = uv,
                .normal = nor,
            });
        }
        try result.indices.append(entry.value_ptr.*);
    }

    return result;
}
