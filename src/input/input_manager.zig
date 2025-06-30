//- src/input/input_manager.zig
//- Handles the input from keyboard and mouse
//- maps them to the glfw code.

const std = @import("std");
const my_std = @import("../util/std_wrapper.zig");
const math = @import("../util/math.zig");
const c = @import("../window/window_builder.zig").c;
const settings = @import("../settings.zig");

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
    M1,
    F5,

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

pub const InputError = error{
    InvalidKeyCode,
    InvalidMouseButton,
    InvalidAction,
    InputManagerNotSet,
    GLFWNotInitialized,
    FileNotFound,
    JsonParseError,
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
    pub fn init(allocator: std.mem.Allocator, input_settings: settings.InputSettings) !InputManager {
        var manager = InputManager{
            .allocator = allocator,
            .key_bindings = std.HashMap(Action, KeyBinding, ActionHasher, 75)
                .initContext(allocator, ActionHasher{}),
        };

        try manager.populateBindings(input_settings.key_bindings);

        return manager;
    }

    fn populateBindings(self: *InputManager, json_bindings: []const settings.JsonKeyBinding) !void {
        self.key_bindings.clearAndFree();

        for (json_bindings) |json_binding| {
            try self.key_bindings.put(json_binding.action, KeyBinding{
                .binding_type = json_binding.binding_type,
                .glfw_code = json_binding.glfw_code,
            });
        }
    }

    pub fn reload_from_json(self: *InputManager, file_path: []const u8) !void {
        const parsed_settings = settings.loadSettings(self.allocator, file_path) catch |err| {
            std.log.err("Error loading settings from '{s}': {}", .{ file_path, err });
            return switch (err) {
                error.FileNotFound => InputError.FileNotFound,
                else => InputError.JsonParseError,
            };
        };
        defer parsed_settings.deinit();
        try self.populateBindings(parsed_settings.value.input.key_bindings);
        std.debug.print("Key bindings reloaded successfully from '{s}'.\n", .{file_path});
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
    fn get_binding_state(self: *const InputManager, action: Action) InputError!State {
        const binding = self.key_bindings.get(action) orelse {
            std.log.warn("No binding found for Action: {s}", .{@tagName(action)});
            return InputError.InvalidAction;
        };
        return switch (binding.binding_type) {
            .Keyboard => {
                if (binding.glfw_code < 0) return InputError.InvalidKeyCode;
                const index: usize = @intCast(binding.glfw_code);
                if (index >= self.keys.len) return InputError.InvalidKeyCode;
                return self.keys[index];
            },
            .Mouse => {
                if (binding.glfw_code < 0) return InputError.InvalidMouseButton;
                const index: usize = @intCast(binding.glfw_code);
                if (index >= self.mouse_buttons.len) return InputError.InvalidMouseButton;
                return self.mouse_buttons[index];
            },
        };
    }

    pub fn get_mouse_delta(self: *const InputManager) struct { dx: f64, dy: f64 } {
        return .{
            .dx = self.mouse_x - self.last_mouse_x,
            .dy = self.mouse_y - self.last_mouse_y,
        };
    }

    pub fn get_mouse_x(self: *const InputManager) f64 {
        return self.mouse_x;
    }

    pub fn get_mouse_y(self: *const InputManager) f64 {
        return self.mouse_y;
    }

    pub fn get_scroll_offset(self: *const InputManager) struct { x: f64, y: f64 } {
        return .{
            .x = self.scroll_x_offset,
            .y = self.scroll_y_offset,
        };
    }

    pub fn is_action_pressed(self: *const InputManager, action: Action) bool {
        const state = self.get_binding_state(action) catch .Up;
        return state == .Pressed;
    }

    pub fn is_action_held(self: *const InputManager, action: Action) bool {
        const state = self.get_binding_state(action) catch .Up;
        return switch (state) {
            .Held, .Pressed => true,
            else => false,
        };
    }

    pub fn is_action_released(self: *const InputManager, action: Action) bool {
        const state = self.get_binding_state(action) catch .Up;
        return state == .Released;
    }

    pub fn glfw_key_callback(
        window: ?*c.GLFWwindow,
        key: c_int,
        _: c_int,
        action: c_int,
        _: c_int,
    ) callconv(.C) void {
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
    ) callconv(.C) void {
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
    ) callconv(.C) void {
        const input_manager = get_input_manager(window);

        input_manager.mouse_x = xpos;
        input_manager.mouse_y = ypos;
    }

    pub fn glfw_scroll_callback(
        window: ?*c.GLFWwindow,
        xoffset: f64,
        yoffset: f64,
    ) callconv(.C) void {
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
