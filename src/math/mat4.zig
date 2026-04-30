//- src/util/math/mat4.zig
const std = @import("std");
const Vector = @import("vector.zig").Vector;
const testing = std.testing;

pub fn Mat4(comptime T: type) type {
    const size = 4;
    const Vec3 = Vector(3, T);
    const Vec4 = Vector(4, T);

    return extern struct {
        const Self = @This();
        cols: [size]Vec4,

        pub fn init(xs: [size][size]T) Self {
            return .{ .cols = .{
                Vec4.init(xs[0]),
                Vec4.init(xs[1]),
                Vec4.init(xs[2]),
                Vec4.init(xs[3]),
            } };
        }

        pub fn toMat3(m: Self) [9]T {
            return .{
                m.cols[0].data[0], m.cols[0].data[1], m.cols[0].data[2],
                m.cols[1].data[0], m.cols[1].data[1], m.cols[1].data[2],
                m.cols[2].data[0], m.cols[2].data[1], m.cols[2].data[2],
            };
        }

        pub fn identity() Self {
            return .init(.{
                .{ 1, 0, 0, 0 },
                .{ 0, 1, 0, 0 },
                .{ 0, 0, 1, 0 },
                .{ 0, 0, 0, 1 },
            });
        }

        pub fn translate(v: Vec3) Self {
            return init(.{
                .{ 1, 0, 0, 0 },
                .{ 0, 1, 0, 0 },
                .{ 0, 0, 1, 0 },
                .{ v.data[0], v.data[1], v.data[2], 1 },
            });
        }

        pub fn scale(v: Vec3) Self {
            return init(.{
                .{ v.data[0], 0, 0, 0 },
                .{ 0, v.data[1], 0, 0 },
                .{ 0, 0, v.data[2], 0 },
                .{ 0, 0, 0, 1 },
            });
        }

        pub fn rotateY(angle: T) Self {
            const cos = @cos(angle);
            const sin = @sin(angle);
            return init(.{
                .{ cos, 0, sin, 0 },
                .{ 0, 1, 0, 0 },
                .{ -sin, 0, cos, 0 },
                .{ 0, 0, 0, 1 },
            });
        }

        pub fn rotateX(angle: T) Self {
            const cos = @cos(angle);
            const sin = @sin(angle);
            return init(.{
                .{ 1, 0, 0, 0 },
                .{ 0, cos, -sin, 0 },
                .{ 0, sin, cos, 0 },
                .{ 0, 0, 0, 1 },
            });
        }

        pub fn rotateZ(angle: T) Self {
            const cos = @cos(angle);
            const sin = @sin(angle);
            return init(.{
                .{ cos, -sin, 0, 0 },
                .{ sin, cos, 0, 0 },
                .{ 0, 0, 1, 0 },
                .{ 0, 0, 0, 1 },
            });
        }

        pub fn mul(a: Self, b: Self) Self {
            var result: Self = undefined;
            inline for (0..size) |col| {
                result.cols[col] = a.mulVec(b.cols[col]);
            }
            return result;
        }

        pub fn mulVec(m: Self, v: Vec4) Vec4 {
            var result: @Vector(size, T) = @splat(0);
            inline for (0..size) |col| {
                result += m.cols[col].data * @as(@Vector(size, T), @splat(v.data[col]));
            }
            return .{ .data = result };
        }

        pub fn transpose(m: Self) Self {
            var result: Self = undefined;
            inline for (0..size) |col| {
                inline for (0..size) |row| {
                    result.cols[col].data[row] = m.cols[row].data[col];
                }
            }
            return result;
        }

        pub fn lookAt(eye: Vec3, target: Vec3, up: Vec3) Self {
            const f = target.sub(eye).normalize();
            const r = f.cross(up).normalize();
            const u = r.cross(f);

            return init(.{
                .{ r.data[0], u.data[0], -f.data[0], 0 },
                .{ r.data[1], u.data[1], -f.data[1], 0 },
                .{ r.data[2], u.data[2], -f.data[2], 0 },
                .{ -r.dot(eye), -u.dot(eye), f.dot(eye), 1 },
            });
        }

        pub fn perspective(fov: T, aspect: T, near: T, far: T) Self {
            const t = @tan(fov / 2.0);
            return init(.{
                .{ 1.0 / (aspect * t), 0, 0, 0 },
                .{ 0, 1.0 / t, 0, 0 },
                .{ 0, 0, -(far + near) / (far - near), -1 },
                .{ 0, 0, -(2 * far * near) / (far - near), 0 },
            });
        }
    };
}

const Vec3f = Vector(3, f32);
const Mat4f = Mat4(f32);
const eps = std.math.floatEps(f32) * 10;

test "mat4 identity mul" {
    const i = Mat4f.identity();
    const result = i.mul(i);
    inline for (0..4) |col| {
        inline for (0..4) |row| {
            try testing.expectApproxEqAbs(i.cols[col].data[row], result.cols[col].data[row], eps);
        }
    }
}

test "mat4 transpose" {
    const m = Mat4f.init(.{
        .{ 1, 2, 3, 4 },
        .{ 5, 6, 7, 8 },
        .{ 9, 10, 11, 12 },
        .{ 13, 14, 15, 16 },
    });
    const t = m.transpose();
    inline for (0..4) |col| {
        inline for (0..4) |row| {
            try testing.expectApproxEqAbs(m.cols[row].data[col], t.cols[col].data[row], eps);
        }
    }
}

test "mat4 transpose twice is identity" {
    const m = Mat4f.init(.{
        .{ 1, 2, 3, 4 },
        .{ 5, 6, 7, 8 },
        .{ 9, 10, 11, 12 },
        .{ 13, 14, 15, 16 },
    });
    const tt = m.transpose().transpose();
    inline for (0..4) |col| {
        inline for (0..4) |row| {
            try testing.expectApproxEqAbs(m.cols[col].data[row], tt.cols[col].data[row], eps);
        }
    }
}

test "mat4 mulVec identity" {
    const Vec4 = Vector(4, f32);
    const m = Mat4f.identity();
    const v = Vec4.init(.{ 1, 2, 3, 4 });
    const result = m.mulVec(v);
    inline for (0..4) |i| {
        try testing.expectApproxEqAbs(v.data[i], result.data[i], eps);
    }
}

test "mat4 lookAt produces unit axes for aligned input" {
    const eye = Vec3f.init(.{ 0, 0, 0 });
    const target = Vec3f.init(.{ 0, 0, -1 });
    const up = Vec3f.init(.{ 0, 1, 0 });
    const m = Mat4f.lookAt(eye, target, up);

    try testing.expectApproxEqAbs(@as(f32, 1), m.cols[0].data[0], eps);
    try testing.expectApproxEqAbs(@as(f32, 0), m.cols[0].data[1], eps);
    try testing.expectApproxEqAbs(@as(f32, 0), m.cols[0].data[2], eps);

    try testing.expectApproxEqAbs(@as(f32, 0), m.cols[1].data[0], eps);
    try testing.expectApproxEqAbs(@as(f32, 1), m.cols[1].data[1], eps);
    try testing.expectApproxEqAbs(@as(f32, 0), m.cols[1].data[2], eps);
}

test "mat4 lookAt no translation when eye at origin" {
    const eye = Vec3f.init(.{ 0, 0, 0 });
    const target = Vec3f.init(.{ 0, 0, -1 });
    const up = Vec3f.init(.{ 0, 1, 0 });
    const m = Mat4f.lookAt(eye, target, up);

    try testing.expectApproxEqAbs(@as(f32, 0), m.cols[3].data[0], eps);
    try testing.expectApproxEqAbs(@as(f32, 0), m.cols[3].data[1], eps);
    try testing.expectApproxEqAbs(@as(f32, 0), m.cols[3].data[2], eps);
    try testing.expectApproxEqAbs(@as(f32, 1), m.cols[3].data[3], eps);
}

test "mat4 lookAt eye offset produces translation" {
    const eye = Vec3f.init(.{ 1, 2, 3 });
    const target = Vec3f.init(.{ 1, 2, 2 });
    const up = Vec3f.init(.{ 0, 1, 0 });
    const m = Mat4f.lookAt(eye, target, up);

    try testing.expectApproxEqAbs(@as(f32, -1), m.cols[3].data[0], eps);
    try testing.expectApproxEqAbs(@as(f32, -2), m.cols[3].data[1], eps);
    try testing.expectApproxEqAbs(@as(f32, -3), m.cols[3].data[2], eps);
}

test "mat4 lookAt right vector is perpendicular to up and forward" {
    const eye = Vec3f.init(.{ 1, 2, 3 });
    const target = Vec3f.init(.{ 4, 5, 6 });
    const up = Vec3f.init(.{ 0, 1, 0 });
    const m = Mat4f.lookAt(eye, target, up);

    const right = Vec3f.init(.{ m.cols[0].data[0], m.cols[0].data[1], m.cols[0].data[2] });
    const u = Vec3f.init(.{ m.cols[1].data[0], m.cols[1].data[1], m.cols[1].data[2] });
    const fwd = Vec3f.init(.{ m.cols[2].data[0], m.cols[2].data[1], m.cols[2].data[2] });

    try testing.expectApproxEqAbs(@as(f32, 0), right.dot(u), eps);
    try testing.expectApproxEqAbs(@as(f32, 0), right.dot(fwd), eps);
    try testing.expectApproxEqAbs(@as(f32, 0), u.dot(fwd), eps);

    try testing.expectApproxEqAbs(@as(f32, 1), @sqrt(right.length()), eps);
    try testing.expectApproxEqAbs(@as(f32, 1), @sqrt(u.length()), eps);
    try testing.expectApproxEqAbs(@as(f32, 1), @sqrt(fwd.length()), eps);
}

test "mat4 perspective w column" {
    const fov = std.math.pi / 2.0;
    const aspect: f32 = 16.0 / 9.0;
    const near: f32 = 0.1;
    const far: f32 = 100.0;
    const m = Mat4f.perspective(fov, aspect, near, far);

    try testing.expectApproxEqAbs(@as(f32, 0), m.cols[0].data[3], eps);
    try testing.expectApproxEqAbs(@as(f32, 0), m.cols[1].data[3], eps);
    try testing.expectApproxEqAbs(@as(f32, -1), m.cols[2].data[3], eps);
    try testing.expectApproxEqAbs(@as(f32, 0), m.cols[3].data[3], eps);
}

test "mat4 perspective near plane maps to -1" {
    const fov = std.math.pi / 2.0;
    const aspect = 16.0 / 9.0;
    const near: f32 = 0.1;
    const far: f32 = 100.0;
    const m = Mat4f.perspective(fov, aspect, near, far);

    const Vec4 = Vector(4, f32);
    const p = Vec4.init(.{ 0, 0, -near, 1 });
    const clip = m.mulVec(p);
    const ndc_z = clip.data[2] / clip.data[3];
    try testing.expectApproxEqAbs(@as(f32, -1), ndc_z, 1e-5);
}

test "mat4 perspective far plane maps to 1" {
    const fov = std.math.pi / 2.0;
    const aspect = 16.0 / 9.0;
    const near: f32 = 0.1;
    const far: f32 = 100.0;
    const m = Mat4f.perspective(fov, aspect, near, far);

    const Vec4 = Vector(4, f32);
    const p = Vec4.init(.{ 0, 0, -far, 1 });
    const clip = m.mulVec(p);
    const ndc_z = clip.data[2] / clip.data[3];
    try testing.expectApproxEqAbs(@as(f32, 1), ndc_z, 1e-4);
}
