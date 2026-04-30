const std = @import("std");
const c = @import("../bindings.zig").c;
const types = @import("./types.zig");
const config = @import("../../core/config.zig");

pub const State = types.State;
pub const Action = types.Action;
pub const Binding = types.Binding;
pub const KeyBinding = types.KeyBinding;

pub const InputError = error{
    InvalidKeyCode,
    InvalidMouseButton,
    InvalidAction,
    InputManagerNotSet,
    GLFWNotInitialized,
    FileNotFound,
    JsonParseError,
};

const ActionHasher = struct {
    pub fn hash(_: @This(), key: Action) u64 {
        return @intFromEnum(key);
    }
    pub fn eql(_: @This(), a: Action, b: Action) bool {
        return a == b;
    }
};

pub const InputManager = struct {
    keys: [512]State = [_]State{.Up} ** 512,
    mouse_buttons: [8]State = [_]State{.Up} ** 8,

    mouse_x: f64 = 0.0,
    mouse_y: f64 = 0.0,
    last_mouse_x: f64 = 0.0,
    last_mouse_y: f64 = 0.0,

    scroll_x_offset: f64 = 0.0,
    scroll_y_offset: f64 = 0.0,

    allocator: std.mem.Allocator,
    key_bindings: std.HashMap(Action, KeyBinding, ActionHasher, 75),

    pub fn init(allocator: std.mem.Allocator, input_config: config.InputConfig) !InputManager {
        var manager = InputManager{
            .allocator = allocator,
            .key_bindings = std.HashMap(Action, KeyBinding, ActionHasher, 75)
                .initContext(allocator, ActionHasher{}),
        };
        try manager.populateBindings(input_config.key_bindings);
        return manager;
    }

    pub fn deinit(self: *InputManager) void {
        self.key_bindings.deinit();
    }

    pub fn reload(self: *InputManager, input_config: config.InputConfig) !void {
        try self.populateBindings(input_config.key_bindings);
        std.log.info("Input bindings reloaded.", .{});
    }

    fn populateBindings(self: *InputManager, bindings: []const config.JsonKeyBinding) !void {
        self.key_bindings.clearAndFree();
        for (bindings) |b| {
            try self.key_bindings.put(b.action, KeyBinding{
                .binding_type = b.binding_type,
                .glfw_code = b.glfw_code,
            });
        }
    }

    pub fn update(self: *InputManager) void {
        for (&self.keys) |*state| {
            state.* = switch (state.*) {
                .Pressed => .Held,
                .Released => .Up,
                else => state.*,
            };
        }
        for (&self.mouse_buttons) |*state| {
            state.* = switch (state.*) {
                .Pressed => .Held,
                .Released => .Up,
                else => state.*,
            };
        }
        self.scroll_x_offset = 0.0;
        self.scroll_y_offset = 0.0;
        self.last_mouse_x = self.mouse_x;
        self.last_mouse_y = self.mouse_y;
    }

    fn getBindingState(self: *const InputManager, action: Action) InputError!State {
        const binding = self.key_bindings.get(action) orelse {
            std.log.warn("No binding for action: {s}", .{@tagName(action)});
            return InputError.InvalidAction;
        };
        return switch (binding.binding_type) {
            .Keyboard => {
                if (binding.glfw_code < 0 or binding.glfw_code >= self.keys.len)
                    return InputError.InvalidKeyCode;
                return self.keys[@intCast(binding.glfw_code)];
            },
            .Mouse => {
                if (binding.glfw_code < 0 or binding.glfw_code >= self.mouse_buttons.len)
                    return InputError.InvalidMouseButton;
                return self.mouse_buttons[@intCast(binding.glfw_code)];
            },
        };
    }

    pub fn isKeyPressed(self: *const InputManager, glfw_code: c_int) bool {
        if (glfw_code < 0 or glfw_code >= self.keys.len) return false;
        return self.keys[@intCast(glfw_code)] == .Pressed;
    }

    pub fn isActionPressed(self: *const InputManager, action: Action) bool {
        return (self.getBindingState(action) catch .Up) == .Pressed;
    }

    pub fn isActionHeld(self: *const InputManager, action: Action) bool {
        return switch (self.getBindingState(action) catch .Up) {
            .Held, .Pressed => true,
            else => false,
        };
    }

    pub fn isActionReleased(self: *const InputManager, action: Action) bool {
        return (self.getBindingState(action) catch .Up) == .Released;
    }

    pub fn getMouseDelta(self: *const InputManager) struct { dx: f64, dy: f64 } {
        return .{ .dx = self.mouse_x - self.last_mouse_x, .dy = self.mouse_y - self.last_mouse_y };
    }

    pub fn getScrollOffset(self: *const InputManager) struct { x: f64, y: f64 } {
        return .{ .x = self.scroll_x_offset, .y = self.scroll_y_offset };
    }

    pub fn glfw_key_callback(
        window: ?*c.GLFWwindow,
        key: c_int,
        _: c_int,
        action: c_int,
        _: c_int,
    ) callconv(.c) void {
        const input_manager = get_input_manager(window);

        const key_id: usize = @intCast(key);
        if (key_id >= input_manager.keys.len or key_id < 0) {
            std.log.warn("GLFW key code {d} out of bounds for InputManager.keys array.", .{key});
            return;
        }

        switch (action) {
            c.GLFW_PRESS => {
                input_manager.keys[key_id] = .Pressed;
            },
            c.GLFW_RELEASE => {
                input_manager.keys[key_id] = .Released;
            },
            c.GLFW_REPEAT => {
                input_manager.keys[key_id] = .Held;
            },
            else => {},
        }
    }

    pub fn glfw_mouse_callback(
        window: ?*c.GLFWwindow,
        button: c_int,
        action: c_int,
        _: c_int,
    ) callconv(.c) void {
        const input_manager = get_input_manager(window);

        const button_id: usize = @intCast(button);
        if (button_id >= input_manager.mouse_buttons.len or button_id < 0) {
            std.log.warn("GLFW mouse button {d} out of bounds for InputManager.mouse_buttons arra.", .{button});
            return;
        }

        switch (action) {
            c.GLFW_PRESS => {
                input_manager.mouse_buttons[button_id] = .Pressed;
            },
            c.GLFW_RELEASE => {
                input_manager.mouse_buttons[button_id] = .Released;
            },
            else => {},
        }
    }

    pub fn glfw_cursor_position_callback(
        window: ?*c.GLFWwindow,
        xpos: f64,
        ypos: f64,
    ) callconv(.c) void {
        const input_manager = get_input_manager(window);

        input_manager.mouse_x = xpos;
        input_manager.mouse_y = ypos;
    }

    pub fn glfw_scroll_callback(
        window: ?*c.GLFWwindow,
        xoffset: f64,
        yoffset: f64,
    ) callconv(.c) void {
        const input_manager = get_input_manager(window);

        input_manager.scroll_x_offset += xoffset;
        input_manager.scroll_y_offset += yoffset;
    }

    fn get_input_manager(window: ?*c.GLFWwindow) *InputManager {
        const ptr = c.glfwGetWindowUserPointer(window).?;
        const aligned_ptr: *align(@alignOf(InputManager)) anyopaque = @alignCast(ptr);
        const input_manager_ptr: *InputManager = @ptrCast(aligned_ptr);
        return input_manager_ptr;
    }
};
