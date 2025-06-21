//- src/util/std_wrapper.zig
//-
//- This is a std wrapper to future proof certain std calls
//- that might break later.
const std = @import("std");

///
///
///
///
pub const std_wrapper = struct {
    allocator_instance: std.mem.Allocator,
    gpa: std.heap.GeneralPurposeAllocator(.{}),

    //---------------Memory---------------\\

    ///
    ///
    ///
    pub fn init() std_wrapper {
        var gpa_instance = std.heap.GeneralPurposeAllocator(.{}){};
        return std_wrapper{
            .allocator_instance = gpa_instance.allocator(),
            .gpa = gpa_instance,
        };
    }

    ///
    ///
    ///
    pub fn deinit(self: *std_wrapper) void {
        const deinit_status = self.gpa.deinit();
        if (deinit_status == .leak) {
            std.log.err("Memory leak detected during StdWrapper deinitialization: {s}", .{@tagName(deinit_status)});
        }
    }

    ///
    ///
    ///
    pub fn allocator(self: *const std_wrapper) std.mem.Allocator {
        return self.allocator_instance;
    }

    //---------------Print---------------\\

    ///Uses std.debug.print
    ///
    ///@param The string that you want to debug print.
    ///@param Pass an args you want to be printed.
    pub fn print(comptime format: []const u8, args: anytype) void {
        std.debug.print(format, args);
    }
};
