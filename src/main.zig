const std = @import("std");
const wb = @import("platform/window.zig");
const in = @import("platform/input/input.zig");
const zn = @import("zengine.zig");
const t = @import("core/time.zig");
const c = wb.c;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var engine = try zn.ZEngine.init(allocator, .{});
    engine.window.setUserPointer(&engine.input);
    engine.window.registerCallbacks(in.InputManager);
    defer engine.deinit();

    while (engine.update()) {
        engine.draw();
    }
}
