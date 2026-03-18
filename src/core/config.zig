const std = @import("std");
const types = @import("../platform/input/types.zig");

pub const Config = struct {
    title: [:0]const u8 = "zengine",
    window: WindowConfig = .{},
    input: InputConfig = .{},
};

pub const WindowConfig = struct {
    width: u32 = 1280,
    height: u32 = 720,
    fullscreen: bool = false,
    refresh_rate: u32 = 60,
    max_fps: u32 = 60,
    vsync: bool = true,
};

pub const InputConfig = struct {
    key_bindings: []const JsonKeyBinding = &.{},
};

pub const JsonKeyBinding = struct {
    action: types.Action,
    binding_type: types.Binding,
    glfw_code: i32,
};

pub fn load(allocator: std.mem.Allocator, base: Config, file_path: []const u8) !std.json.Parsed(Config) {
    const file = std.fs.cwd().openFile(file_path, .{ .mode = .read_only }) catch |err| {
        std.log.warn("Could not open config file '{s}': {}", .{ file_path, err });
        return err;
    };
    defer file.close();

    _ = base;

    const contents = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(contents);

    return std.json.parseFromSlice(Config, allocator, contents, .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = true,
    });
}
