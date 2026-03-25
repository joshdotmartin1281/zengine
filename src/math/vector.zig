const std = @import("std");
const testing = std.testing;

pub fn Vector(comptime size: usize, comptime T: type) type {
    const internal_size = if (size == 3) 4 else size;
    const VecType = @Vector(internal_size, T);

    return extern struct {
        const Self = @This();

        data: VecType,
        pub const len = size;

        pub fn init(xs: [size]T) Self {
            var v: VecType = @splat(@as(T, 0));
            inline for (0..size) |i| {
                v[i] = xs[i];
            }
            return .{ .data = v };
        }

        pub fn add(a: Self, b: Self) Self {
            return .{ .data = a.data + b.data };
        }

        pub fn sub(a: Self, b: Self) Self {
            return .{ .data = a.data - b.data };
        }

        pub fn mul(a: Self, b: Self) Self {
            return .{ .data = a.data * b.data };
        }

        pub fn div(a: Self, b: Self) Self {
            return .{ .data = a.data / b.data };
        }

        pub fn dot(a: Self, b: Self) T {
            return @reduce(.Add, a.data * b.data);
        }

        //[x,y,z]*[x',y',z'] = yzx * zxy  →  [y*z', z*x', x*y']
        //                     zxy * yzx  →  [z*y', x*z', y*x']
        pub fn cross(a: Self, b: Self) Self {
            comptime if (internal_size != 4 or size != 3) @compileError("Cross product must only be done on vectors of size 3.");

            const a_yzx = @shuffle(T, a.data, undefined, [4]i32{ 1, 2, 0, 3 });
            const b_yzx = @shuffle(T, b.data, undefined, [4]i32{ 1, 2, 0, 3 });
            const a_zxy = @shuffle(T, a.data, undefined, [4]i32{ 2, 0, 1, 3 });
            const b_zxy = @shuffle(T, b.data, undefined, [4]i32{ 2, 0, 1, 3 });
            var result: VecType = a_yzx * b_zxy - a_zxy * b_yzx;
            result[3] = 0;

            return .{ .data = result };
        }

        pub fn scale(a: Self, scalar: T) Self {
            return .{ .data = a.data * @as(VecType, @splat(scalar)) };
        }

        pub fn normalize(a: Self) Self {
            const d: T = @sqrt(dot(a, a));
            return .{ .data = a.data / @as(VecType, @splat(d)) };
        }

        ///Remember len is sqrt of dot. To skip the unnecessary operation do x * x.
        pub fn length(a: Self) T {
            return dot(a, a);
        }

        pub fn lerp(a: Self, b: Self, t: f32) Self {
            return a.add(b.sub(a).scale(t));
        }
    };
}

const eps = std.math.floatEps(f32) * 10;

fn approxEq(a: f32, b: f32) bool {
    return @abs(a - b) < eps;
}

fn vec3Eq(a: Vector(3, f32), b: Vector(3, f32)) bool {
    return approxEq(a.data[0], b.data[0]) and
        approxEq(a.data[1], b.data[1]) and
        approxEq(a.data[2], b.data[2]);
}

const Vec3 = Vector(3, f32);
const Vec2 = Vector(2, f32);

test "vec3 add" {
    const a = Vec3.init(.{ 1, 2, 3 });
    const b = Vec3.init(.{ 4, 5, 6 });
    try std.testing.expect(vec3Eq(a.add(b), Vec3.init(.{ 5, 7, 9 })));
}

test "vec3 add zero" {
    const a = Vec3.init(.{ 1, 2, 3 });
    const zero = Vec3.init(.{ 0, 0, 0 });
    try std.testing.expect(vec3Eq(a.add(zero), a));
}

test "vec3 sub" {
    const a = Vec3.init(.{ 4, 5, 6 });
    const b = Vec3.init(.{ 1, 2, 3 });
    try std.testing.expect(vec3Eq(a.sub(b), Vec3.init(.{ 3, 3, 3 })));
}

test "vec3 sub self is zero" {
    const a = Vec3.init(.{ 1, 2, 3 });
    try std.testing.expect(vec3Eq(a.sub(a), Vec3.init(.{ 0, 0, 0 })));
}

// --- dot ---
test "vec3 dot perpendicular is zero" {
    const x = Vec3.init(.{ 1, 0, 0 });
    const y = Vec3.init(.{ 0, 1, 0 });
    try std.testing.expectApproxEqAbs(@as(f32, 0), x.dot(y), eps);
}

test "vec3 dot parallel" {
    const a = Vec3.init(.{ 2, 0, 0 });
    try std.testing.expectApproxEqAbs(@as(f32, 4), a.dot(a), eps);
}

test "vec3 dot general" {
    const a = Vec3.init(.{ 1, 2, 3 });
    const b = Vec3.init(.{ 4, 5, 6 });
    try std.testing.expectApproxEqAbs(@as(f32, 32), a.dot(b), eps);
}

test "vec3 cross basis vectors" {
    const x = Vec3.init(.{ 1, 0, 0 });
    const y = Vec3.init(.{ 0, 1, 0 });
    const z = Vec3.init(.{ 0, 0, 1 });
    try std.testing.expect(vec3Eq(x.cross(y), z));
    try std.testing.expect(vec3Eq(y.cross(z), x));
    try std.testing.expect(vec3Eq(z.cross(x), y));
}

test "vec3 cross anticommutative" {
    const a = Vec3.init(.{ 1, 2, 3 });
    const b = Vec3.init(.{ 4, 5, 6 });
    const ab = a.cross(b);
    const ba = b.cross(a);
    try std.testing.expect(vec3Eq(ab, Vec3.init(.{ -ba.data[0], -ba.data[1], -ba.data[2] })));
}

test "vec3 cross parallel is zero" {
    const a = Vec3.init(.{ 1, 2, 3 });
    try std.testing.expect(vec3Eq(a.cross(a), Vec3.init(.{ 0, 0, 0 })));
}

test "vec3 cross perpendicular to both inputs" {
    const a = Vec3.init(.{ 1, 2, 3 });
    const b = Vec3.init(.{ 4, 5, 6 });
    const c = a.cross(b);
    try std.testing.expectApproxEqAbs(@as(f32, 0), c.dot(a), eps);
    try std.testing.expectApproxEqAbs(@as(f32, 0), c.dot(b), eps);
}

test "vec3 length unit vector" {
    const x = Vec3.init(.{ 1, 0, 0 });
    try std.testing.expectApproxEqAbs(@as(f32, 1), x.length(), eps);
}

test "vec3 length general" {
    const a = Vec3.init(.{ 3, 4, 0 });
    try std.testing.expectApproxEqAbs(@as(f32, 5), @sqrt(a.length()), eps);
}

test "vec3 normalize produces unit vector" {
    const a = Vec3.init(.{ 3, 4, 0 });
    try std.testing.expectApproxEqAbs(@as(f32, 1), a.normalize().length(), eps);
}

test "vec3 normalize preserves direction" {
    const a = Vec3.init(.{ 2, 0, 0 });
    try std.testing.expect(vec3Eq(a.normalize(), Vec3.init(.{ 1, 0, 0 })));
}

test "vec2 add" {
    const a = Vec2.init(.{ 1, 2 });
    const b = Vec2.init(.{ 3, 4 });
    try std.testing.expectApproxEqAbs(@as(f32, 4), a.add(b).data[0], eps);
    try std.testing.expectApproxEqAbs(@as(f32, 6), a.add(b).data[1], eps);
}

test "vec2 dot" {
    const a = Vec2.init(.{ 1, 0 });
    const b = Vec2.init(.{ 0, 1 });
    try std.testing.expectApproxEqAbs(@as(f32, 0), a.dot(b), eps);
}
