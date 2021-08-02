const std = @import("std");

const termelot = @import("termelot");

pub fn log(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    termelot.log(level, scope, format, args);
}

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const config = termelot.Config{
        .raw_mode = false,
        .alternate_screen = false,
        .initial_buffer_size = null, // We don't care
    };

    var term: termelot.Termelot = undefined;
    term = term.init(&gpa.allocator, config) catch |e| {
        std.log.crit("Termelot could not be initialized! Error: {}", .{e});
        return;
    };
    defer _ = term.deinit();
}
