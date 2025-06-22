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
///Input manager
pub const InputManager = struct {
    //Add arrays of keys and mouse buttons
    //as well as the
    allocator: std.mem.Allocator,

    ///init the input manager mapping it to a hashmap.
    pub fn init(allocator: std.mem.Allocator) !InputManager {
        var manager = InputManager{
            .allocator = allocator,
            .key_bindings = std.HashMap(Action, KeyBinding, Action.hash, Action.eql).init(allocator),
        };

        try manager.key_bindings.put(.Forward, KeyBinding{ .binding_type = .Keyboard, .glfw_code = c.GLFW_KEY_W });
        try manager.key_bindings.put(.Backward, KeyBinding{ .binding_type = .Keyboard, .glfw_code = c.GLFW_KEY_S });
        try manager.key_bindings.put(.Left, KeyBinding{ .binding_type = .Keyboard, .glfw_code = c.GLFW_KEY_A });
        try manager.key_bindings.put(.Right, KeyBinding{ .binding_type = .Keyboard, .glfw_code = c.GLFW_KEY_D });

        return manager;
    }
    /// deinit the input manager.
    pub fn deinit(self: *InputManager) void {
        self.key_bindings.deinit();
    }
};
