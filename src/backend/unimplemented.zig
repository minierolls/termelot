// Copyright (c) 2020 Termelot Contributors.

// SPDX-License-Identifier: MIT
// This file is part of the Termelot project under the MIT license.

const termelot_import = @import("../termelot.zig");
const Termelot = termelot_import.Termelot;
const Config = termelot_import.Config;

pub const Backend = struct {
    // Add desired backend fields here; the `Backend` struct's fields
    // will *never* be accessed, so add/remove as needed.
    const Self = @This();

    /// Initialize backend
    pub fn init(
        termelot: *Termelot,
        allocator: *std.mem.allocator,
        config: Config,
    ) !Backend {
        @compileError("Unimplemented");
    }

    /// Deinitialize backend
    pub fn deinit(self: *Self) void {
        @compileError("Unimplemented");
    }

    /// Retrieve raw mode status.
    pub fn getRawMode() !bool {
        @compileError("Unimplemented");
    }

    /// Enter/exit raw mode.
    pub fn setRawMode(enabled: bool) !void {
        @compileError("Unimplemented");
    }

    /// Retrieve alternate screen status.
    pub fn getAlternateScreen() !bool {
        @compileError("Unimplemented");
    }

    /// Enter/exit alternate screen.
    pub fn setAlternateScreen(enabled: bool) !void {
        @compileError("Unimplemented");
    }

    /// Start event/signal handling loop, non-blocking immediate return.
    pub fn start(self: *Self) !void {
        // This function should call necessary functions for screen size
        // update, key event callbacks, and mouse event callbacks.
        @compileError("Unimplemented");
    }

    /// Stop event/signal handling loop.
    pub fn stop(self: *Self) void {
        @compileError("Unimplemented");
    }

    /// Set terminal title.
    pub fn setTitle(self: *Self, runes: []Rune) !void {
        @compileError("Unimplemented");
    }

    /// Get screen size.
    pub fn getScreenSize(self: *Self) !Position {
        // This function will only be called once on
        // startup, and then the size should be set
        // through the event handling loop.
        @compileError("Unimplemented");
    }

    /// Get cursor position.
    pub fn getCursorPosition(self: *Self) !Position {
        @compileError("Unimplemented");
    }

    /// Set cursor position.
    pub fn setCursorPosition(self: *Self, position: Position) !void {
        @compileError("Unimplemented");
    }

    /// Get cursor visibility.
    pub fn getCursorVisibility(self: *Self) !bool {
        @compileError("Unimplemented");
    }

    /// Set cursor visibility.
    pub fn setCursorVisibility(self: *Self, visible: bool) !void {
        @compileError("Unimplemented");
    }

    /// Write styled output to screen at position. Assumed that no newline
    /// or carriage return runes are provided.
    pub fn write(
        self: *Self,
        position: Position,
        runes: []Rune,
        styles: []Style,
    ) !void {
        @compileError("Unimplemented");
    }
};
