//- src/util/time.zig
const std = @import("std");
const c = @import("../window/window.zig").c;

pub const Timer = struct {
    last_frame: f64,
    delta_time: f32,
    frame_count: u32 = 0,
    fps_timer: f64 = 0.0,
    current_fps: u32 = 0,

    pub fn init() Timer {
        return. {
            .last_frame = c.glfwGetTime(),
            .delta_time = 0.0,
        };
    }

    pub fn tick(self: *Timer) void {
        const current_time = c.glfwGetTime();
        self.delta_time = @floatCast(current_time - self.last_frame);
        self.last_frame = current_time;

        self.frame_count += 1;
        self.fps_timer += self.delta_time;
        if (self.fps_timer >= 1.0) {
            self.current_fps = self.frame_count;
            self.frame_count = 0;
            self.fps_timer -= 1.0;
            std.debug.print("FPS: {d}\n", .{self.current_fps});
        }
    }
};
