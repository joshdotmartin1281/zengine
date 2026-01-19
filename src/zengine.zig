//- src/zengine.zig
const std = @import("std");
const settings = @import("settings.zig");
const wb = @import("window/window.zig");
const c = wb.c;

pub const zengine = struct {

    settings: std.json.Parsed(settings.AppSettings),
    window: wb.Window,

    pub fn init(allocator: std.mem.Allocator) !zengine {
        const parsed_settings = try settings.loadSettings(allocator, "./src/settings.json");
        const app_cfg = parsed_settings.value;

        const window_instance = try wb.Window.init(
            allocator, 
            app_cfg.window.width, 
            app_cfg.window.height,
            app_cfg.window.fullscreen,
            app_cfg.window.target_refresh_rate_hz,
            app_cfg.title,
        );
        
        return zengine {
            .settings = parsed_settings,
            .window = window_instance,
        };
    }

    //pub fn update() void {

    //}

    pub fn deinit(self: *zengine) void {
        self.settings.deinit();
        self.window.deinit();
    }

    pub fn beginFrame(self: *zengine) void {
        self.window.pollEvents();
        c.glClear(c.GL_COLOR_BUFFER_BIT);
    }

    pub fn endFrame(self: *zengine) void {
        self.window.swapBuffers();
    }

    pub fn shouldClose(self: *zengine) bool {
        return self.window.shouldClose();
    }
};
