//- src/input/input_manager.zig
//- Handles the input from keyboard and mouse
//- maps them to the glfw code.

const std = @import("std");
const my_std = @import("../util/std_wrapper.zig");
const math = @import("../util/math.zig");
const c = @import("../window/window_builder.zig").c;

///Represents the state of the input
pub const State = enum(u8) {
    Up,
    Pressed,
    Held,
    Released,
};

///Abstracts game actions
pub const Action = enum(u8) {
    Forward,
    Backward,
    Right,
    Left,
    Jump,

    pub fn hash(self: Action) u64 {
        return @intFromEnum(self);
    }

    pub fn eql(self: Action, other: Action) bool {
        return self == other;
    }
};

///Abstracts what is being used, keboard or mouse.
pub const Binding = enum(u8) {
    Keyboard,
    Mouse,
};

///Represents the binding for a sing key or mouse button.
pub const KeyBinding = struct {
    binding_type: Binding,
    glfw_code: c.GLint,
};

const ActionHasher = struct {
    pub fn hash(_: @This(), key: Action) u64 {
        return key.hash();
    }

    pub fn eql(_: @This(), a: Action, b: Action) bool {
        return a.eql(b);
    }
};

///Input manager
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

    ///init the input manager mapping it to a hashmap.
    pub fn init(allocator: std.mem.Allocator) !InputManager {
        var manager = InputManager{
            .allocator = allocator,
            .key_bindings = std.HashMap(Action, KeyBinding, ActionHasher, 75)
                .initContext(allocator, ActionHasher{}),
        };

        try manager.key_bindings.put(.Forward, KeyBinding{ .binding_type = .Keyboard, .glfw_code = c.GLFW_KEY_W });
        try manager.key_bindings.put(.Backward, KeyBinding{ .binding_type = .Keyboard, .glfw_code = c.GLFW_KEY_S });
        try manager.key_bindings.put(.Left, KeyBinding{ .binding_type = .Keyboard, .glfw_code = c.GLFW_KEY_A });
        try manager.key_bindings.put(.Right, KeyBinding{ .binding_type = .Keyboard, .glfw_code = c.GLFW_KEY_D });
        try manager.key_bindings.put(.Jump, KeyBinding{ .binding_type = .Keyboard, .glfw_code = c.GLFW_KEY_SPACE });

        return manager;
    }
    /// deinit the input manager.
    pub fn deinit(self: *InputManager) void {
        self.key_bindings.deinit();
    }

    ///Changes the state for the key inside of the map,
    ///pressed to held, released to up if neither of those keep current state.
    ///
    ///@param self a pointer to the InputManager struct.
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

        //reset scroll offset for each frame.
        self.scroll_x_offset = 0.0;
        self.scroll_y_offset = 0.0;

        //get last mouse position.
        self.last_mouse_x = self.mouse_x;
        self.last_mouse_y = self.mouse_y;
    }

    ///
    fn get_binding_state(self: *const InputManager, action: Action) ?State {
        const binding = self.key_bindings.get(action) orelse {
            std.log.warn("No binding found for Action: {s}", .{@tagName(action)});
            return null;
        };
        return switch (binding.binding_type) {
            .Keyboard => {
                if (binding.glfw_code < 0) return .Up;
                const index: usize = @intCast(binding.glfw_code);
                if (index >= self.keys.len) return .Up;
                return self.keys[index];
            },
            .Mouse => {
                if (binding.glfw_code < 0) return .Up;
                const index: usize = @intCast(binding.glfw_code);
                if (index >= self.mouse_buttons.len) return .Up;
                return self.mouse_buttons[index];
            },
        };
    }

    pub fn is_action_pressed(self: *const InputManager, action: Action) bool {
        const state = self.get_binding_state(action);
        return state != null and state.? == .Pressed;
    }

    pub fn is_action_held(self: *const InputManager, action: Action) bool {
        const state = self.get_binding_state(action);
        return state != null and (state.? == .Held or state.? == .Pressed);
    }

    pub fn is_action_released(self: *const InputManager, action: Action) bool {
        const state = self.get_binding_state(action);
        return state != null and state.? == .Released;
    }

    fn get_input_manager(window: ?*c.GLFWwindow) *InputManager {
        const ptr = c.glfwGetWindowUserPointer(window).?;
        const aligned_ptr: *align(@alignOf(InputManager)) anyopaque = @alignCast(ptr);
        const input_manager_ptr: *InputManager = @ptrCast(aligned_ptr);
        return input_manager_ptr;
    }

    // --- GLFW Callback Functions ---

    pub fn glfw_key_callback(
        window: ?*c.GLFWwindow,
        key: c_int,
        _: c_int,
        action: c_int,
        _: c_int,
    ) callconv(.C) void {
        const input_manager = get_input_manager(window);

        const key_idx: usize = @intCast(key);
        if (key_idx >= input_manager.keys.len or key_idx < 0) { // Ensure positive index as well
            std.log.warn("GLFW key code {d} out of bounds for InputManager.keys array.", .{key});
            return;
        }

        switch (action) {
            c.GLFW_PRESS => {
                input_manager.keys[key_idx] = .Pressed;
            },
            c.GLFW_RELEASE => {
                input_manager.keys[key_idx] = .Released;
            },
            c.GLFW_REPEAT => {
                input_manager.keys[key_idx] = .Held;
            },
            else => {},
        }
    }
};
