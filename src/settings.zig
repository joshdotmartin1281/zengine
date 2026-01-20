//- src/settings.zig
const std = @import("std");

pub const AppSettings = struct {
    title: [:0]const u8,
    window: WindowSettings,
    //keys: KeySettings,
    //mouse: MouseSettings,
};

pub const WindowSettings = struct {
    width: u32,
    height: u32,
    fullscreen: bool,
    refresh_rate: u32,
    max_fps: u32,
    vsync: bool,
};

pub const KeySettings = struct {
    glfw_code: u32, 
};

pub const MouseSettings = struct {
    glfw_code: u32,
};

// Function to load and parse settings from a JSON file
pub fn loadSettings(allocator: std.mem.Allocator, file_path: []const u8) !std.json.Parsed(AppSettings) {
    const file = try std.fs.cwd().openFile(file_path, .{ .mode = .read_only });
    defer file.close();

    const file_contents = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(file_contents);

    const parsed_settings = try std.json.parseFromSlice(AppSettings, allocator, file_contents, .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = true,
    });

    return parsed_settings;
}

