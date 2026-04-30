const std = @import("std");
const c = @import("../platform/bindings.zig").c;
const Shader = @import("shader.zig").Shader;
const mesh = @import("mesh.zig");
const Texture = @import("texture.zig").Texture;
const Camera = @import("camera.zig").Camera;
const ObjMesh = @import("obj.zig").ObjMesh;
const Mat4f = @import("../math/mat4.zig").Mat4(f32);
const Vec3 = @import("../math/vector.zig").Vector(3, f32);

pub const RenderObject = struct {
    gpu_mesh: mesh.GpuMesh,
    obj_mesh: ObjMesh,
    texture: Texture,
    transform: Mat4f,

    pub fn deinit(self: *RenderObject) void {
        self.texture.deinit();
        self.gpu_mesh.deinit();
        self.obj_mesh.deinit();
    }
};

pub const Renderer = struct {
    shader: Shader,
    objects: std.ArrayList(RenderObject),
    sun_pos: Vec3,
    flashlight_pos: Vec3,
    flashlight_on: bool,

    pub fn init(allocator: std.mem.Allocator, assets_dir: []const u8) !Renderer {
        c.glEnable(c.GL_DEPTH_TEST);

        const vert_src: [*c]const u8 = @embedFile("shader/vert.glsl");
        const frag_src: [*c]const u8 = @embedFile("shader/frag.glsl");
        const shader = try Shader.init(vert_src, frag_src);
        errdefer shader.deinit();

        var objects = std.ArrayList(RenderObject).init(allocator);
        errdefer {
            for (objects.items) |*o| o.deinit();
            objects.deinit();
        }

        var dir = try std.fs.cwd().openDir(assets_dir, .{ .iterate = true });
        defer dir.close();

        var it = dir.iterate();
        while (try it.next()) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.name, ".obj")) continue;

            const obj_path = try std.fs.path.join(allocator, &.{ assets_dir, entry.name });
            defer allocator.free(obj_path);

            var obj_mesh = ObjMesh.init(allocator);
            errdefer obj_mesh.deinit();
            try obj_mesh.parseObj(obj_path);

            const texture_path = obj_mesh.texture_path orelse {
                std.log.warn("no texture found for {s}, skipping", .{entry.name});
                obj_mesh.deinit();
                continue;
            };

            const texture = Texture.load(texture_path.ptr) catch {
                std.log.warn("failed to load texture for {s}, skipping", .{entry.name});
                obj_mesh.deinit();
                continue;
            };

            var gpu_mesh = try mesh.deindex(&obj_mesh, allocator);
            errdefer gpu_mesh.deinit();
            gpu_mesh.upload();

            try objects.append(.{
                .gpu_mesh = gpu_mesh,
                .obj_mesh = obj_mesh,
                .texture = texture,
                .transform = Mat4f.identity(),
            });

            std.log.info("loaded {s}", .{entry.name});
        }

        return .{
            .shader = shader,
            .objects = objects,
            .sun_pos = Vec3.init(.{ 0, 50, 0 }),
            .flashlight_pos = Vec3.init(.{ 0, 0, 0 }),
            .flashlight_on = true,
        };
    }

    pub fn deinit(self: *Renderer) void {
        for (self.objects.items) |*o| o.deinit();
        self.objects.deinit();
        self.shader.deinit();
    }

    pub fn draw(self: *Renderer, camera: *Camera, aspect: f32, alpha: f32) void {
        const real_pos = camera.position;
        camera.position = camera.interpolatedPosition(alpha);

        const view = camera.viewMatrix();
        const proj = camera.projectionMatrix(aspect);
        const vp = proj.mul(view);

        camera.position = real_pos;

        c.glClearColor(0.1, 0.1, 0.1, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT);

        self.shader.bind();
        self.shader.setMat4("vp", vp);
        self.shader.setVec3("uSunPos", self.sun_pos);
        self.shader.setVec3("uFlashlightPos", self.flashlight_pos);
        self.shader.setVec3("uViewPos", camera.position);
        self.shader.setVec3("uLightColor", Vec3.init(.{ 1.0, 1.0, 1.0 }));
        self.shader.setInt("uFlashlightOn", if (self.flashlight_on) 1 else 0);

        for (self.objects.items) |*o| {
            self.shader.setMat4("model", o.transform);
            self.shader.setMat3("normalMatrix", o.transform.toMat3());
            o.texture.bind(0);
            self.shader.setInt("uTexture", 0);
            o.gpu_mesh.draw();
        }
    }
};
