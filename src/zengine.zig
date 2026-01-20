//- src/zengine.zig
const std = @import("std");
const settings = @import("settings.zig");
const wb = @import("window/window.zig");
const time = @import("util/time.zig");
const input = @import("input/input_manager.zig");
const c = wb.c;

pub const ZEngine = struct {
    allocator: std.mem.Allocator,
    settings: std.json.Parsed(settings.AppSettings),
    window: wb.Window,
    timer: time.Timer,
    max_fps: u32,
    min_frame_time: u64,

    accumulator: f32 = 0.0,
    const target_dt: f32 = 1.0 / 60.0;

    pub fn init(allocator: std.mem.Allocator) !ZEngine {
        const parsed_settings = try settings.loadSettings(allocator, "./src/settings.json");
        const app_cfg = parsed_settings.value;

        const window_instance = try wb.Window.init(allocator, .{
            .title = app_cfg.title,
            .width = app_cfg.window.width, 
            .height = app_cfg.window.height,
            .fullscreen = app_cfg.window.fullscreen,
            .refresh_rate = app_cfg.window.refresh_rate,
            .vsync = app_cfg.window.vsync,
        });
       
        const max_fps = app_cfg.window.max_fps;
        const ns_per_frame = if (max_fps > 0)
            @as(u64, @intFromFloat(@as(f64, std.time.ns_per_s) / @as(f64, @floatFromInt(max_fps))))
        else
            0;

        return ZEngine {
            .allocator = allocator,
            .settings = parsed_settings,
            .window = window_instance,
            .timer = time.Timer.init(),
            .max_fps = max_fps,
            .min_frame_time = ns_per_frame,
        };
    }

    pub fn deinit(self: *ZEngine) void {
        self.window.deinit();
        self.settings.deinit();
    }

    pub fn update(self: *ZEngine) bool {
        if (self.window.shouldClose()) return false;

        self.window.pollEvents();

        self.timer.tick();
        self.accumulator += self.timer.delta_time;

        while (self.accumulator >= target_dt) {
            self.physicsTick(target_dt);
            self.accumulator -= target_dt;
        }

        return true;
    }

    fn physicsTick(self: *ZEngine, dt: f32) void {
        //eventually player.update(dt)
        _ = self; _ = dt; 
    }

    pub fn draw(self: *ZEngine) void {
        const alpha = self.accumulator / target_dt;
        _ = alpha;

        c.glClearColor(0.1, 0.1, 0.1, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT);
        
        //render calls here later.

        self.window.swapBuffers();
        if (self.min_frame_time > 0) {
            const now = @as(u64, @intFromFloat(c.glfwGetTime() * 1e9));
            const start = @as(u64, @intFromFloat(self.timer.last_frame * 1e9));
            const elapsed = now - start;
            if (elapsed < self.min_frame_time) {
                std.Thread.sleep(self.min_frame_time - elapsed);
            }
        }
    }
};
