//- src/util/clock.zig
const std = @import("std");

pub const Clock = struct {
    timer: std.time.Timer,
    last_frame: u64,

    time_scale: f32 = 1.0,
    max_delta: f32 = 0.25,

    pub fn init() !Clock {
        var t = try std.time.Timer.start();
        return .{
            .timer = t,
            .last_frame = t.read(),
        };
    }

    pub fn calculateDelta(self: *Clock) f32 {
        const now = self.timer.read();
        const elapsed = now - self.last_frame;
        self.last_frame = now;

        var dt = @as(f32, @floatFromInt(elapsed)) / @as(f32, @floatFromInt(std.time.ns_per_s));

        if (dt > self.max_delta) dt = self.max_delta;

        return dt * self.time_scale;
    }
};

