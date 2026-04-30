const std = @import("std");
const builtin = @import("builtin");
const config = @import("core/config.zig");
const time = @import("core/time.zig");
const Platform = @import("platform/platform.zig").Platform;
const Renderer = @import("render/renderer.zig").Renderer;
const Camera = @import("render/camera.zig").Camera;
const Vec3 = @import("math/vector.zig").Vector(3, f32);
const c = @import("platform/bindings.zig").c;
const input = @import("platform/input/input.zig");

pub const ZEngine = struct {
    allocator: std.mem.Allocator,
    config: std.json.Parsed(config.Config),
    platform: Platform,
    renderer: Renderer,
    timer: time.Timer,
    camera: Camera,

    pub fn init(allocator: std.mem.Allocator, base: config.Config) !ZEngine {
        const parsed = try config.load(allocator, base, "./src/core/settings.json");
        errdefer parsed.deinit();
        const cfg = parsed.value;

        var platform = try Platform.init(allocator, cfg);
        errdefer platform.deinit();

        var renderer = try Renderer.init(allocator, "assets/models/example2");
        errdefer renderer.deinit();

        const timer_config = time.TimerConfig{
            .target_ups = 60.0,
            .max_fps = cfg.window.max_fps,
            .clock = .{ .time_scale = 1.0, .max_delta = 0.1 },
        };

        return ZEngine{
            .allocator = allocator,
            .config = parsed,
            .platform = platform,
            .renderer = renderer,
            .timer = try time.Timer.init(timer_config),
            .camera = Camera.init(Vec3.init(.{ 0, 0, 3 })),
        };
    }

    pub fn deinit(self: *ZEngine) void {
        self.renderer.deinit();
        self.platform.deinit();
        self.config.deinit();
    }

    pub fn update(self: *ZEngine) bool {
        if (!self.platform.update()) return false;
        self.timer.update();

        if (builtin.mode == .Debug and self.platform.input.isKeyPressed(c.GLFW_KEY_F5)) {
            self.reloadConfig();
        }

        if (self.platform.input.isActionPressed(.Pause)) self.platform.window.unlockCursor();
        if (self.platform.input.isActionPressed(.M1)) self.platform.window.lockCursor();
        if (self.platform.input.isActionPressed(.Flashlight)) self.renderer.flashlight_on = !self.renderer.flashlight_on;

        self.updateCameraLook();
        self.camera.beginFrame();

        var steps: u32 = 0;
        while (self.timer.consumeStep() and steps < 8) : (steps += 1) {
            self.physicsTick(self.timer.target_dt);
        }

        return true;
    }

    fn updateCameraLook(self: *ZEngine) void {
        const sensitivity: f32 = 0.003;
        const delta = self.platform.input.getMouseDelta();
        const dyaw: f32 = @floatCast(delta.dx * sensitivity);
        const dpitch: f32 = @floatCast(-delta.dy * sensitivity);
        self.camera.look(dyaw, dpitch);
    }

    fn reloadConfig(self: *ZEngine) void {
        const reparsed = config.load(self.allocator, self.config.value, "./src/core/settings.json") catch |err| {
            std.log.warn("Config reload failed: {}", .{err});
            return;
        };
        self.config.deinit();
        self.config = reparsed;
        self.platform.reload(self.config.value) catch |err| {
            std.log.warn("Input reload failed: {}", .{err});
        };
        std.log.info("Config reloaded.", .{});
    }

    fn physicsTick(self: *ZEngine, dt: f32) void {
        const speed: f32 = if (self.platform.input.isActionHeld(.Sprint)) 2.0 else 1.0;
        const forward = self.camera.forward();
        const right = forward.cross(Vec3.init(.{ 0, 1, 0 })).normalize();

        if (self.platform.input.isActionHeld(.Forward)) self.camera.move(forward.scale(speed * dt));
        if (self.platform.input.isActionHeld(.Backward)) self.camera.move(forward.scale(-speed * dt));
        if (self.platform.input.isActionHeld(.Left)) self.camera.move(right.scale(-speed * dt));
        if (self.platform.input.isActionHeld(.Right)) self.camera.move(right.scale(speed * dt));
        if (self.platform.input.isActionHeld(.Jump)) self.camera.move(Vec3.init(.{ 0, speed * dt, 0 }));
        if (self.platform.input.isActionHeld(.Crouch)) self.camera.move(Vec3.init(.{ 0, -speed * dt, 0 }));

        self.renderer.flashlight_pos = self.camera.position;
    }

    pub fn draw(self: *ZEngine) void {
        const alpha = self.timer.getAlpha();
        const aspect = self.platform.window.aspectRatio();
        self.renderer.draw(&self.camera, aspect, alpha);
        self.platform.window.swapBuffers();
        self.timer.capFrameRate();
    }
};
