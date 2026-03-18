pub const State = enum(u8) {
    Up,
    Pressed,
    Held,
    Released,
};

pub const Action = enum(u8) {
    Forward,
    Backward,
    Right,
    Left,
    Jump,
    Crouch,
    Sprint,
    Pause,
    M1,
    M2,
};

pub const Binding = enum(u8) {
    Keyboard,
    Mouse,
};

pub const KeyBinding = struct {
    binding_type: Binding,
    glfw_code: i32,
};
