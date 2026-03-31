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

    pub fn debugPrint(self: *const Self) void {
        std.debug.print("vertices ({d}):\n", .{self.vertices.items.len});
        for (self.vertices.items, 0..) |v, i| {
            std.debug.print("  [{d}] pos=({d:.3}, {d:.3}, {d:.3}) uv=({d:.3}, {d:.3}) nor=({d:.3}, {d:.3}, {d:.3})\n", .{
                i,
                v.position.data[0], v.position.data[1], v.position.data[2],
                v.texcoord.data[0], v.texcoord.data[1],
                v.normal.data[0],   v.normal.data[1],   v.normal.data[2],
            });
        }

        std.debug.print("indices ({d}):\n", .{self.indices.items.len});
        var i: usize = 0;
        while (i + 2 < self.indices.items.len) : (i += 3) {
            std.debug.print("  tri {d}: {d}, {d}, {d}\n", .{
                i / 3,
                self.indices.items[i],
                self.indices.items[i + 1],
                self.indices.items[i + 2],
            });
        }
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
            const uv = if (face.vt) |t| mesh.texcoords.items[t] else Vec2.init( .{ 0, 0 } );
            const nor = if (face.vn) |n| mesh.normals.items[n] else Vec3.init( .{ 0, 0, 0 } );

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


