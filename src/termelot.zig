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
    pub fn pollEvent(self: *Self, struct { timeout: i32 = 0 }) !?Event {
        return self.backend.pollEvent(timeout);
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

    pub fn getCells(
        self: Self,
        position: Position,
        length: u16,
        result: *[length]Cell,
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
