const std = @import("std");
const Vec3 = @import("../math/vector.zig").Vector(3, f32);
const Mat4f = @import("../math/mat4.zig").Mat4(f32);

pub const Camera = struct {
    position: Vec3,
    previous_position: Vec3,
    yaw: f32,
    pitch: f32,
    fov: f32,
    near: f32,
    far: f32,

    pub fn init(pos: Vec3) Camera {
        return .{
            .position = pos,
            .previous_position = pos,
            .yaw = -std.math.pi / 2.0,
            .pitch = 0,
            .fov = std.math.pi / 4.0,
            .near = 0.1,
            .far = 100.0,
        };
    }

    pub fn viewMatrix(self: Camera) Mat4f {
        const target = self.position.add(self.forward());
        return Mat4f.lookAt(self.position, target, Vec3.init(.{ 0, 1, 0 }));
    }

    pub fn projectionMatrix(self: Camera, aspect: f32) Mat4f {
        return Mat4f.perspective(self.fov, aspect, self.near, self.far);
    }

    pub fn forward(self: Camera) Vec3 {
        return Vec3.init(.{
            @cos(self.pitch) * @cos(self.yaw),
            @sin(self.pitch),
            @cos(self.pitch) * @sin(self.yaw),
        }).normalize();
    }

    pub fn move(self: *Camera, delta: Vec3) void {
        self.position = self.position.add(delta);
    }

    pub fn beginFrame(self: *Camera) void {
        self.previous_position = self.position;
    }

    pub fn look(self: *Camera, dyaw: f32, dpitch: f32) void {
        self.yaw += dyaw;
        self.pitch += dpitch;
        self.pitch = std.math.clamp(
            self.pitch,
            -std.math.pi / 2.0 + 0.01,
            std.math.pi / 2.0 - 0.01,
        );
    }

    pub fn interpolatedPosition(self: Camera, alpha: f32) Vec3 {
        return self.previous_position.lerp(self.position, alpha);
    }

    pub fn setPosition(self: *Camera, pos: Vec3) void {
        self.position = pos;
    }
};
