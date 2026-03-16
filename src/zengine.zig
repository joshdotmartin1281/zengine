const std = @import("std");
const settings = @import("settings/settings.zig");
const wb = @import("window/window.zig");
const time = @import("util/time.zig");
const input = @import("input/input_manager.zig");
const Shader = @import("graphics/shader.zig").Shader;
const Triangle = @import("graphics/triangle.zig").Triangle;
const Camera = @import("graphics/camera.zig").Camera;
const c = wb.c;

pub const ZEngine = struct {
    allocator: std.mem.Allocator,
    settings: std.json.Parsed(settings.AppSettings),
    window: wb.Window,
    timer: time.Timer,
    shader: Shader,
    triangle: Triangle,
    camera: Camera,

    pub fn init(allocator: std.mem.Allocator) !ZEngine {
        const parsed_settings = try settings.loadSettings(allocator, "./src/settings/settings.json");
        const app_cfg = parsed_settings.value;
        const window_instance = try wb.Window.init(allocator, .{
            .title = app_cfg.title,
            .width = app_cfg.window.width,
            .height = app_cfg.window.height,
            .fullscreen = app_cfg.window.fullscreen,
            .refresh_rate = app_cfg.window.refresh_rate,
            .vsync = app_cfg.window.vsync,
        });
        const timer_config = time.TimerConfig{
            .target_ups = 60.0,
            .max_fps = app_cfg.window.max_fps,
            .clock = .{ .time_scale = 1.0, .max_delta = 0.1 },
        };

        const vert_src: [*c]const u8 = @embedFile("shaders/vert.glsl");
        const frag_src: [*c]const u8 = @embedFile("shaders/frag.glsl");

        return ZEngine{
            .allocator = allocator,
            .settings = parsed_settings,
            .window = window_instance,
            .timer = try time.Timer.init(timer_config),
            .shader = try Shader.init(vert_src, frag_src),
            .triangle = Triangle.init(),
            .camera = Camera.init(),
        };
    }

    pub fn deinit(self: *ZEngine) void {
        self.shader.deinit();
        self.triangle.deinit();
        self.window.deinit();
        self.settings.deinit();
    }

    pub fn update(self: *ZEngine) bool {
        if (self.window.shouldClose()) return false;
        self.window.pollEvents();
        self.timer.update();
        var steps: u32 = 0;
        while (self.timer.consumeStep() and steps < 8) : (steps += 1) {
            self.physicsTick(self.timer.target_dt);
        }
        return true;
    }

    fn physicsTick(self: *ZEngine, dt: f32) void {
        self.camera.position.data[0] += 0.5 * dt;
        self.camera.position.data[1] += 0.5 * dt;
        self.camera.position.data[2] += 0.5 * dt;
    }

    pub fn draw(self: *ZEngine) void {
        const aspect = self.window.aspectRatio();

        const view = self.camera.viewMatrix();
        const proj = self.camera.projectionMatrix(aspect);
        const vp = proj.mul(view);

        c.glClearColor(0.1, 0.1, 0.1, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT);

        self.shader.bind();
        self.shader.setMat4("vp", vp);
        self.triangle.draw();

        self.window.swapBuffers();
        self.timer.capFrameRate();
    }
};
