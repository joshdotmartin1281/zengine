//- src/settings.zig
const std = @import("std");
const input = @import("input/input_manager.zig");

// Represents a single key binding within the JSON
pub const JsonKeyBinding = struct {
    action: input.Action,
    binding_type: input.Binding,
    glfw_code: i32,
};

// Represents the overall structure for input settings in the JSON
pub const InputSettings = struct {
    key_bindings: []const JsonKeyBinding,
    //can add mouse support
};

// The top-level struct for your application settings
pub const AppSettings = struct {
    input: InputSettings,
    //window: WindowSettings,
};

pub const WindowSettings = struct {
    width: u32,
    height: u32,
    fullscreen: bool,
    target_refresh_rate_hz: u32,
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
