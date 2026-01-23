//- src/util/time.zig
const std = @import("std");
const c = @import("../window/window.zig").c;


//__CHANGE__ Add a clock struct that calculates the delta and changes the timerstate
pub const Timer = struct {
    timer: std.time.Timer,
    last_frame: u64,
    delta_time: f32 = 0.0,

    // Physics
    accumulator: f32 = 0.0,
    target_dt: f32,

    // Frame capping
    min_frame_time: u64,

    // FPS tracking
    frame_count: u32 = 0,
    fps_timer: f64 = 0.0,
    current_fps: u32 = 0,

    pub fn init(target_ups: f32, max_fps: u32) !Timer {
        const ns_per_frame = if (max_fps > 0)
            @as(u64, @intFromFloat(@as(f64, std.time.ns_per_s) / @as(f64, @floatFromInt(max_fps))))
        else
            0; 

        var t = try std.time.Timer.start();

        return. {
            .timer = t,
            .last_frame = t.read(),
            .target_dt = 1.0 / target_ups,
            .min_frame_time = ns_per_frame,
        };
    }

    pub fn tick(self: *Timer) void {
        const now = self.timer.read();
        const elapsed_ns = now - self.last_frame;
        self.last_frame = now;

        self.delta_time = @as(f32, @floatFromInt(elapsed_ns)) / @as(f32, @floatFromInt(std.time.ns_per_s));
        self.accumulator += self.delta_time;

        self.frame_count += 1;
        self.fps_timer += self.delta_time;
        if (self.fps_timer >= 1.0) {
            self.current_fps = self.frame_count;
            self.frame_count = 0;
            self.fps_timer -= 1.0;
            std.debug.print("FPS: {d}\n", .{self.current_fps});
        }
    }

    pub fn consumeStep(self: *Timer) bool {
        if (self.accumulator >= self.target_dt) {
            self.accumulator -= self.target_dt;
            return true;
        }
        return false;
    }

    pub fn getAlpha(self: *Timer) f32 {
        return self.accumulator / self.target_dt;
    }

    pub fn capFrameRate(self: *Timer) void {
        if (self.min_frame_time == 0) return;

        while (true) {
            const now = self.timer.read();
            const elapsed = now - self.last_frame;
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
