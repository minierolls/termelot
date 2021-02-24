// Copyright (c) 2020 Termelot Contributors.

// SPDX-License-Identifier: MIT
// This file is part of the Termelot project under the MIT license.

const std = @import("std");

pub const style = @import("style.zig");
usingnamespace style;
pub const event = @import("event.zig");

pub const Backend = @import("backend.zig").backend.Backend;
pub const Buffer = @import("buffer.zig").Buffer;
pub const Rune = @import("rune.zig").Rune;

pub const Config = struct {
    raw_mode: bool,
    alternate_screen: bool,
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
    callbacks: std.ArrayList(event.EventCallback),
    cursor_position: Position,
    cursor_visible: bool,
    screen_size: Size,
    screen_buffer: Buffer,
    backend: Backend,

    const Self = @This();

    /// This function should be called *after* declaring a `Termelot` struct:
    ///     var termelot: Termelot = undefined;        OR
    ///     var termelot = @as(Termelot, undefined);
    pub fn init(
        self: *Self,
        allocator: *std.mem.Allocator,
        config: Config,
        initial_buffer_size: ?Size,
    ) !void {
        self.callbacks = std.ArrayList(event.EventCallback).init(allocator);
        errdefer self.callbacks.deinit();
        self.backend = try Backend.init(self, allocator, config);
        errdefer self.backend.deinit();
        self.config = config;
        if (config.raw_mode) {
            try self.backend.setRawMode(true);
        }
        if (config.alternate_screen) {
            try self.backend.setAlternateScreen(true);
        }
        self.supported_features = try self.backend.getSupportedFeatures();
        self.cursor_position = try self.backend.getCursorPosition();
        self.cursor_visible = try self.backend.getCursorVisibility();
        self.screen_size = try self.backend.getScreenSize();
        self.screen_buffer = try Buffer.init(
            &self.backend,
            allocator,
            initial_buffer_size,
        );
        errdefer self.screen_buffer.deinit();

        try self.backend.start();
    }

    pub fn deinit(self: *Self) void {
        if (self.config.alternate_screen) {
            self.backend.setAlternateScreen(false) catch {};
        }
        if (self.config.raw_mode) {
            self.backend.setRawMode(false) catch {};
        }
        self.backend.stop();
        self.screen_buffer.deinit();
        self.backend.deinit();
        self.callbacks.deinit();
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

    pub fn callCallbacks(self: Self, e: event.Event) void {
        const time = std.time.milliTimestamp();
        for (self.callbacks.items) |callback| {
            callback.call(e, time);
        }
    }
    pub fn registerCallback(
        self: *Self,
        new_callback: event.EventCallback,
    ) !void {
        for (self.callbacks.items) |callback| {
            if (std.meta.eql(callback, new_callback)) {
                return;
            }
        }
        try self.callbacks.append(new_callback);
    }
    pub fn deleteCallback(
        self: *Self,
        del_callback: event.EventCallback,
    ) void {
        var remove_index: usize = self.callbacks.items.len;
        for (self.callbacks.items) |callback, index| {
            if (std.meta.eql(callback, del_callback)) {
                remove_index = index;
                break;
            }
        }
        if (remove_index < self.callbacks.items.len) {
            _ = self.callbacks.orderedRemove(remove_index);
        }
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
