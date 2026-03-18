//- src/util/time.zig
const std = @import("std");
const Clock = @import("./clock.zig").Clock;
const ClockConfig = @import("./clock.zig").ClockConfig;
const c = @import("../platform/window.zig").c;

pub const TimerConfig = struct { target_ups: f32 = 60.0, max_fps: u32 = 0, clock: ClockConfig = .{} };

pub const Timer = struct {
    clock: Clock,
    config: TimerConfig,

    delta_time: f32 = 0.0,
    accumulator: f32 = 0.0,
    frame_start: u64 = 0,
    total_time: f32 = 0.0,

    fps: u32 = 0,
    fps_frame_count: u32 = 0,
    fps_accumulator: f32 = 0.0,

    target_dt: f32,
    min_frame_time: u64,

    pub fn init(config: TimerConfig) !Timer {
        const ns_per_frame = if (config.max_fps > 0)
            @as(u64, @intFromFloat(@as(f64, std.time.ns_per_s) / @as(f64, @floatFromInt(config.max_fps))))
        else
            0;

        return .{
            .clock = try Clock.init(),
            .config = config,
            .target_dt = 1.0 / config.target_ups,
            .min_frame_time = ns_per_frame,
        };
    }

    pub fn update(self: *Timer) void {
        if (self.frame_start == 0) {
            self.frame_start = self.clock.timer.read();
        }

        self.delta_time = self.clock.calculateDelta(self.config.clock);
        self.accumulator += self.delta_time;
        self.total_time += self.delta_time;

        const unscaled_dt = if (self.config.clock.time_scale > 0.0)
            self.delta_time / self.config.clock.time_scale
        else
            0.0;
        self.fps_accumulator += unscaled_dt;
        self.fps_frame_count += 1;

        if (self.fps_accumulator >= 0.1) {
            self.fps = @as(u32, @intFromFloat(@as(f32, @floatFromInt(self.fps_frame_count)) / self.fps_accumulator));
            self.fps_accumulator = 0.0;
            self.fps_frame_count = 0;
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

    pub fn updateDerivedValues(self: *Timer) void {
        self.target_dt = 1.0 / self.config.target_ups;
        self.min_frame_time = if (self.config.max_fps > 0)
            @as(u64, @intFromFloat(@as(f64, std.time.ns_per_s) / @as(f64, @floatFromInt(self.config.max_fps))))
        else
            0;
    }

    pub fn capFrameRate(self: *Timer) void {
        if (self.min_frame_time == 0) return;

        while (true) {
            const now = self.clock.timer.read();
            const elapsed = now - self.frame_start;
            if (elapsed >= self.min_frame_time) {
                self.frame_start = now;
                break;
            }

            const remaining = self.min_frame_time - elapsed;
            if (remaining > 1_500_000) {
                std.Thread.sleep(remaining - 1_000_000);
            } else {
                std.atomic.spinLoopHint();
            }
        }
    }

    pub fn setTimeScale(self: *Timer, scale: f32) void {
        self.config.clock.time_scale = std.math.clamp(scale, 0.0, 10.0);
    }

    pub fn pause(self: *Timer) void {
        self.config.clock.time_scale = 0.0;
    }

    pub fn isPaused(self: *const Timer) bool {
        return self.config.clock.time_scale == 0.0;
    }

    pub fn unpause(self: *Timer) void {
        self.config.clock.time_scale = 1.0;
    }

    pub fn setMaxDelta(self: *Timer, max_dt: f32) void {
        self.config.clock.max_delta = @max(0.0, max_dt);
    }
};
