const std = @import("std");
const wb = @import("window/window.zig");
const zn = @import("zengine.zig");
const t = @import("util/time.zig");
const c = wb.c;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var engine = try zn.ZEngine.init(allocator);
    defer engine.deinit();

    while (engine.update()) {
        engine.draw();
    }
}
