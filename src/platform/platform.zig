const std = @import("std");
const builtin = @import("builtin");
const Window = @import("window.zig").Window;
const input = @import("input/input.zig");
const config = @import("../core/config.zig");

pub const Platform = struct {
    window: Window,
    input: input.InputManager,

    pub fn init(allocator: std.mem.Allocator, cfg: config.Config) !Platform {
        var window = try Window.init(allocator, .{
            .title = cfg.title,
            .width = cfg.window.width,
            .height = cfg.window.height,
            .fullscreen = cfg.window.fullscreen,
            .refresh_rate = cfg.window.refresh_rate,
            .vsync = cfg.window.vsync,
        });
        errdefer window.deinit();

        var input_manager = try input.InputManager.init(allocator, cfg.input);
        errdefer input_manager.deinit();

        return .{
            .window = window,
            .input = input_manager,
        };
    }

    pub fn deinit(self: *Platform) void {
        self.input.deinit();
        self.window.deinit();
    }

    pub fn update(self: *Platform) bool {
        if (self.window.shouldClose()) return false;
        self.input.update();
        self.window.pollEvents();
        return true;
    }

    pub fn reload(self: *Platform, cfg: config.Config) !void {
        try self.input.reload(cfg.input);
    }
};
