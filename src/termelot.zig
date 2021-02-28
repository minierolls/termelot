// Copyright (c) 2020 Termelot Contributors.

// SPDX-License-Identifier: MIT
// This file is part of the Termelot project under the MIT license.

const std = @import("std");

pub const style = @import("style.zig");
usingnamespace style;
pub const event = @import("event.zig");
usingnamespace event;

pub const Backend = @import("backend.zig").backend.Backend;
pub const Buffer = @import("buffer.zig").Buffer;
pub const Rune = @import("rune.zig").Rune;

const termelot_log = std.log.scoped(.termelot);

// Overriding std implementation of log. This function does not actually override because this is only
// a library. Although, users of the library are encouraged to override the `log()` function themselves and
// only forward the arguments to this implementation, because it might make their lives easier.
pub fn log(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    const prefix = "[" ++ @tagName(scope) ++ ":" ++ @tagName(level) ++ "] ";

    var buf = [_]u8 { ' ' } ** 1024; // Reserve array of 1024 bytes in stack
    var exe_dir = std.fs.cwd().openDir(std.fs.selfExeDirPath(&buf) catch return, .{ .access_sub_paths = true }) catch return;
    defer exe_dir.close();
    var log_file = exe_dir.createFile(
        "log.txt",
        // TODO: we want to create an exclusive lock on file writing, but allow other processes to read,
        // and not block the return of this function or logging (allow io to be blocked, not the program)
        .{ .read = true, .truncate = false }, // We prefer to append to the log if it exists
    ) catch return;
    defer log_file.close();

    // Seek to end of file (to append data)
    log_file.seekFromEnd(0) catch return;

    const writer = log_file.writer();
    nosuspend writer.print(prefix ++ format ++ "\n", args) catch return;
}

pub const Config = struct {
    raw_mode: bool,
    alternate_screen: bool,
    initial_buffer_size: ?Size,
};
pub const SupportedFeatures = struct {
    color_types: struct {
        Named16: bool,
        Bit8: bool,
        Bit24: bool,
    },
    decorations: Decorations,
};

pub const Size = packed struct {
    rows: u16,
    cols: u16,
};

pub const Position = packed struct {
    row: u16,
    col: u16,
};

pub const Cell = struct {
    rune: Rune,
    style: Style,
};

pub const Termelot = struct {
    config: Config,
    supported_features: SupportedFeatures,
    allocator: *std.mem.Allocator,
    cursor_position: Position,
    cursor_visible: bool,
    screen_size: Size,
    screen_buffer: Buffer,
    backend: Backend,

    const Self = @This();

    pub fn init(
        allocator: *std.mem.Allocator,
        config: Config,
    ) !Termelot {
        var backend = try Backend.init(allocator, config);
        errdefer backend.deinit();
        
        if (config.raw_mode) {
            try backend.setRawMode(true);
        }
        if (config.alternate_screen) {
            try backend.setAlternateScreen(true);
        }

        return Termelot{
            .config = config,
            .supported_features = try backend.getSupportedFeatures(),
            .allocator = allocator,
            .cursor_position = try backend.getCursorPosition(),
            .cursor_visible = try backend.getCursorVisibility(),
            .screen_size = try backend.getScreenSize(),
            .screen_buffer = try Buffer.init(
                &backend,
                allocator,
                config.initial_buffer_size,
            ),
            .backend = backend,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.config.alternate_screen) {
            self.backend.setAlternateScreen(false) catch {};
        }
        if (self.config.raw_mode) {
            self.backend.setRawMode(false) catch {};
        }
        self.screen_buffer.deinit();
        self.backend.deinit();
    }

    /// Polls for an event. If the optional `timeout` parameter has a value greater than 0,
    /// the function will not block and returns null whenever `timeout` milliseconds
    /// has elapsed and no event could be fetched. Function returns immediately upon finding
    /// an Event.
    pub fn pollEvent(self: *Self, opt: struct { timeout: i32 = 0 }) !?event.Event {
        return self.backend.pollEvent(opt.timeout);
    }

    /// Set the Termelot-aware screen size. This does NOT resize the physical
    /// terminal screen, and should not be called by users in most cases. This
    /// is intended for use primarily by the backend.
    pub fn setScreenSize(self: *Self, screen_size: Size) void {
        self.screen_size = screen_size;
    }

    pub fn setTitle(self: *Self, title: []const Rune) !void {
        try self.backend.setTitle(title);
    }

    pub fn setCursorPosition(self: *Self, position: Position) !void {
        try self.backend.setCursorPosition(position);
        self.cursor_position = position;
    }

    pub fn setCursorVisibility(self: *Self, visible: bool) !void {
        try self.backend.setCursorVisibility(visible);
        self.cursor_visible = visible;
    }

    pub fn drawScreen(self: *Self) !void {
        const orig_cursor_position = self.cursor_position;
        try self.screen_buffer.draw(self.screen_size);
        try self.setCursorPosition(orig_cursor_position);
    }

    /// Clears the screen buffer for next draw.
    pub fn clearScreen(self: *Self) void {
        self.screen_buffer.clear();
    }

    pub fn getCell(self: Self, position: Position) ?Cell {
        return self.screen_buffer.getCell(position);
    }

    /// Get a slice of cells within the buffer. This slice cannot span across
    /// rows. Results will be placed in provided "result", and the number of
    /// cells filled will be returned (only less than the specified length if
    /// the slice extends past the edges of the buffer). If position is outside
    /// the buffer, `null` is returned instead.
    ///
    /// `result` is a slice of at least length `length` to write the cells
    /// into.
    pub fn getCells(
        self: Self,
        position: Position,
        length: u16,
        result: []Cell,
    ) ?u16 {
        return self.screen_buffer.getCells(position, length, result);
    }

    pub fn setCell(self: *Self, position: Position, new_cell: Cell) void {
        self.screen_buffer.setCell(position, new_cell);
    }

    pub fn setCells(self: *Self, position: Position, new_cells: []Cell) void {
        self.screen_buffer.setCells(position, new_cells);
    }

    pub fn fillCells(
        self: *Self,
        position: Position,
        length: u16,
        new_cell: Cell,
    ) void {
        self.screen_buffer.fillCells(position, length, new_cell);
    }
};

test "Termelot refAllDecls" {
    std.testing.refAllDecls(Termelot);
}
