const std = @import("std");
const zn = @import("zengine.zig");
const input = @import("platform/input/input.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var engine = try zn.ZEngine.init(allocator, .{});
    defer engine.deinit();

    engine.platform.window.setUserPointer(@ptrCast(&engine.platform.input));
    engine.platform.window.registerCallbacks(input.InputManager);

    while (engine.update()) {
        engine.draw();
    }
}
