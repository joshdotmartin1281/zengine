//- src/util/time.zig
const std = @import("std");
const Clock = @import("./clock.zig").Clock;
const c = @import("../window/window.zig").c;

pub const Timer = struct {
    clock: Clock,
    delta_time: f32 = 0.0,

    //FPS tracking
    fps: u32 = 0,
    fps_frame_count: u32 = 0,
    fps_accumulator: f32 = 0.0,

    // Physics
    accumulator: f32 = 0.0,
    target_dt: f32,

    // Frame capping
    min_frame_time: u64,

    pub fn init(target_ups: f32, max_fps: u32) !Timer {
        const ns_per_frame = if (max_fps > 0)
            @as(u64, @intFromFloat(@as(f64, std.time.ns_per_s) / @as(f64, @floatFromInt(max_fps))))
        else
            0; 

        return. {
            .clock = try Clock.init(),
            .target_dt = 1.0 / target_ups,
            .min_frame_time = ns_per_frame,
        };
    }

    pub fn update(self: *Timer) void {
        self.delta_time = self.clock.calculateDelta();
        self.accumulator += self.delta_time;

        self.fps_accumulator += self.delta_time;
        self.fps_frame_count += 1;

        if (self.fps_accumulator >= 0.1) {
            self.fps = @as(u32, @intFromFloat(@as(f32, @floatFromInt(self.fps_frame_count)) / self.fps_accumulator));
            self.fps_accumulator = 0.0;
            self.fps_frame_count = 0;
            //std.debug.print("FPS: {d}\n", .{self.fps});
        }
    }

    pub fn getAlpha(self: *Timer) f32 {
        return self.accumulator / self.target_dt;
    }

    pub fn consumeStep(self: *Timer) bool {
        if (self.accumulator >= self.target_dt) {
            self.accumulator -= self.target_dt;
            return true;
        }
        return false;
    }

    pub fn setTimeScale(self: *Timer, scale: f32) void {
       self.clock.time_scale = @max(0.0, scale);
    }

    pub fn setMaxDelta(self: *Timer, max_dt: f32) void {
        self.clock.max_delta = max_dt;
    }

    pub fn capFrameRate(self: *Timer) void {
        if (self.min_frame_time == 0) return;

        while (true) {
            const now = self.clock.timer.read();
            const elapsed = now - self.clock.last_frame;
            if (elapsed >= self.min_frame_time) break;

            const remaining = self.min_frame_time - elapsed;

            if (remaining > 1_500_000) {
                std.Thread.sleep(remaining - 1_000_000);
            } else {
                std.atomic.spinLoopHint();
            }
        }
    }
};
