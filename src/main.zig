const std = @import("std");
const wb = @import("window/window.zig");
const zn = @import("zengine.zig");
const c = wb.c; 

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var engine = try zn.zengine.init(allocator);
    defer engine.deinit();

    c.glClearColor(0.2, 0.3, 0.3, 1.0);

    while (!engine.shouldClose()) {
        engine.beginFrame();

        //engine.update();
        //engine.physics();

        engine.endFrame();
    }
}
