// Copyright (c) 2020 Termelot Contributors.

// SPDX-License-Identifier: MIT
// This file is part of the Termelot project under the MIT license.

const std = @import("std");

const termelot = @import("../termelot.zig");
usingnamespace termelot.style;
usingnamespace termelot.event;
const BackendName = termelot.backend.BackendName;
const Config = termelot.Config;
const Position = termelot.Position;
const Rune = termelot.Rune;
const Size = termelot.Size;
const SupportedFeatures = termelot.SupportedFeatures;

pub const Backend = struct {
    // Add desired backend fields here; the `Backend` struct's fields
    // will *never* be accessed, so add/remove as needed.

    const Self = @This();

    /// The tag of a backend is like its identifier. It is used in the build system, and by users
    /// for comptime code.
    pub const tag = BackendName.unimplemented;

    /// Initialize backend
    pub fn init(
        allocator: *std.mem.Allocator,
        config: Config,
    ) !Backend {
        // function body
        return error.Unimplemented;
    }

    /// Deinitialize backend
    pub fn deinit(self: *Self) void {
        // function body
    }

    /// Retrieve supported features for this backend.
    pub fn getSupportedFeatures(self: *Self) !SupportedFeatures {
        // function body
        return error.Unimplemented;
    }

    /// Retrieve raw mode status.
    pub fn getRawMode(self: *Self) !bool {
        // function body
        return error.Unimplemented;
    }

    /// Enter/exit raw mode.
    pub fn setRawMode(self: *Self, enabled: bool) !void {
        // function body
    }

    /// If timeout is less than or equal to zero:
    /// Blocking; return next available Event if one is present, and null otherwise.
    /// If timeout is greater than zero:
    /// Non-blocking; return next available Event if one arises within `timeout` ms.
    pub fn pollEvent(self: *Self, timeout: i32) !?Event {
        // function body
        return error.Unimplemented;
    }

    /// Retrieve alternate screen status.
    pub fn getAlternateScreen(self: *Self) !bool {
        // function body
        return error.Unimplemented;
    }

    /// Enter/exit alternate screen.
    pub fn setAlternateScreen(self: *Self, enabled: bool) !void {
        // function body
    }

    /// If timeout is less than or equal to zero:
    /// Blocking; return next available Event if one is present, and null otherwise.
    /// If timeout is greater than zero:
    /// Non-blocking; return next available Event if one arises within `timeout` ms.
    pub fn pollEvent(self: *Self, timeout: i32) !?Event {
        return error.Unimplemented;
    }

    /// Set terminal title.
    pub fn setTitle(self: *Self, runes: []const Rune) !void {
        // function body
    }

    /// Get screen size.
    pub fn getScreenSize(self: *Self) !Size {
        // This function will only be called once on
        // startup, and then the size should be set
        // through the event handling loop.
        return error.Unimplemented;
    }

    /// Get cursor position.
    pub fn getCursorPosition(self: *Self) !Position {
        // function body
        return error.Unimplemented;
    }

    /// Set cursor position.
    pub fn setCursorPosition(self: *Self, position: Position) !void {
        // function body
    }

    /// Get cursor visibility.
    pub fn getCursorVisibility(self: *Self) !bool {
        // function body
        return error.Unimplemented;
    }

    /// Set cursor visibility.
    pub fn setCursorVisibility(self: *Self, visible: bool) !void {
        // function body
    }

    /// Write styled output to screen at position. Assumed that no newline
    /// or carriage return runes are provided.
    pub fn write(
        self: *Self,
        position: Position,
        runes: []Rune,
        styles: []Style,
    ) !void {
        // function body
    }
};
