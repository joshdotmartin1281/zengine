const std = @import("std");
const builtin = @import("builtin");
const config = @import("core/config.zig");
const wb = @import("platform/window.zig");
const time = @import("core/time.zig");
const input = @import("platform/input/input.zig");
const Shader = @import("render/shader.zig").Shader;
const Camera = @import("render/camera.zig").Camera;
const Vec3 = @import("math/vector.zig").Vector(3, f32);
const ObjMesh = @import("render/obj.zig").ObjMesh;
const mesh = @import("render/mesh.zig");
const c = wb.c;

pub const ZEngine = struct {
    allocator: std.mem.Allocator,
    config: std.json.Parsed(config.Config),
    window: wb.Window,
    timer: time.Timer,
    input: input.InputManager,
    shader: Shader,
    camera: Camera,
    objMesh: ObjMesh,
    gpuMesh: mesh.GpuMesh,

    pub fn init(allocator: std.mem.Allocator, base: config.Config) !ZEngine {
        const parsed = try config.load(allocator, base, "./src/core/settings.json");
        errdefer parsed.deinit();
        const cfg = parsed.value;

        var window_instance = try wb.Window.init(allocator, .{
            .title = cfg.title,
            .width = cfg.window.width,
            .height = cfg.window.height,
            .fullscreen = cfg.window.fullscreen,
            .refresh_rate = cfg.window.refresh_rate,
            .vsync = cfg.window.vsync,
        });
        errdefer window_instance.deinit();

        c.glEnable(c.GL_DEPTH_TEST);

        var input_manager = try input.InputManager.init(allocator, cfg.input);
        errdefer input_manager.deinit();

        const timer_config = time.TimerConfig{
            .target_ups = 60.0,
            .max_fps = cfg.window.max_fps,
            .clock = .{ .time_scale = 1.0, .max_delta = 0.1 },
        };

        var objMesh = ObjMesh.init(allocator);
        errdefer objMesh.deinit();
        try objMesh.parseObj("assets/models/example1.obj");
        objMesh.debugPrint();

        const vert_src: [*c]const u8 = @embedFile("render/shader/vert.glsl");
        const frag_src: [*c]const u8 = @embedFile("render/shader/frag.glsl");

        const shader = try Shader.init(vert_src, frag_src);
        errdefer shader.deinit();

        var gpuMesh = try mesh.deindex(&objMesh, allocator);
        errdefer gpuMesh.deinit();
        gpuMesh.upload();
        gpuMesh.debugPrint();

        return ZEngine{
            .allocator = allocator,
            .config = parsed,
            .window = window_instance,
            .timer = try time.Timer.init(timer_config),
            .input = input_manager,
            .shader = shader,
            .objMesh = objMesh,
            .gpuMesh = gpuMesh,
            .camera = Camera.init(Vec3.init(.{ 0, 0, 3 })),
        };
    }

    pub fn deinit(self: *ZEngine) void {
        self.shader.deinit();
        self.input.deinit();
        self.window.deinit();
        self.config.deinit();
        self.objMesh.deinit();
        self.gpuMesh.deinit();
    }

    pub fn update(self: *ZEngine) bool {
        if (self.window.shouldClose()) return false;
        self.input.update();
        self.timer.update();
        self.window.pollEvents();

        if (builtin.mode == .Debug and self.input.isKeyPressed(c.GLFW_KEY_F5)) {
            self.reloadConfig();
        }

        if (self.input.isActionPressed(.Pause)) self.window.unlockCursor();
        if (self.input.isActionPressed(.M1)) self.window.lockCursor();

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
        const delta = self.input.getMouseDelta();
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
        self.input.reload(self.config.value.input) catch |err| {
            std.log.warn("Input reload failed: {}", .{err});
        };
        std.log.info("Config reloaded.", .{});
    }

    fn physicsTick(self: *ZEngine, dt: f32) void {
        const speed: f32 = if (self.input.isActionHeld(.Sprint)) 2.0 else 1.0;

        const forward = self.camera.forward();
        const right = forward.cross(Vec3.init(.{ 0, 1, 0 })).normalize();

        if (self.input.isActionHeld(.Forward)) {
            self.camera.move(forward.scale(speed * dt));
        }
        if (self.input.isActionHeld(.Backward)) {
            self.camera.move(forward.scale(-speed * dt));
        }
        if (self.input.isActionHeld(.Left)) {
            self.camera.move(right.scale(-speed * dt));
        }
        if (self.input.isActionHeld(.Right)) {
            self.camera.move(right.scale(speed * dt));
        }
        if (self.input.isActionHeld(.Jump)) {
            self.camera.move(Vec3.init(.{ 0, speed * dt, 0 }));
        }
        if (self.input.isActionHeld(.Crouch)) {
            self.camera.move(Vec3.init(.{ 0, -speed * dt, 0 }));
        }
    }

    pub fn draw(self: *ZEngine) void {
        const alpha = self.timer.getAlpha();
        const aspect = self.window.aspectRatio();

        const real_pos = self.camera.position;
        self.camera.position = self.camera.interpolatedPosition(alpha);

        const view = self.camera.viewMatrix();
        const proj = self.camera.projectionMatrix(aspect);
        const vp = proj.mul(view);

        self.camera.position = real_pos;

        c.glClearColor(0.1, 0.1, 0.1, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT);
        self.shader.bind();
        self.shader.setMat4("vp", vp);
        self.gpuMesh.draw();
        self.window.swapBuffers();
        self.timer.capFrameRate();
    }
};
