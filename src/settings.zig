//- src/settings.zig
const std = @import("std");
const input = @import("input/input_manager.zig"); // Import your InputManager Action and Binding enums

// Represents a single key binding within the JSON
pub const JsonKeyBinding = struct {
    action: input.Action, // Corresponds to your InputManager.Action enum
    binding_type: input.Binding, // Corresponds to your InputManager.Binding enum
    glfw_code: i32, // Use i32 because c.GLint is typically int (which is i32)
};

// Represents the overall structure for input settings in the JSON
pub const InputSettings = struct {
    key_bindings: []const JsonKeyBinding, // Array of key bindings
    // You could add other input-related settings here, like mouse sensitivity,
    // or device overrides as discussed previously, if you expand the JSON.
};

// The top-level struct for your application settings
pub const AppSettings = struct {
    input: InputSettings,
    // Add other top-level settings sections here (e.g., graphics, audio)
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
