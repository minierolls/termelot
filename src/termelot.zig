// Copyright (c) 2020 Termelot Contributors.

// SPDX-License-Identifier: MIT
// This file is part of the Termelot project under the MIT license.

const std = @import("std");

pub const style = @import("style.zig");
pub const event = @import("event.zig");

pub const Backend = @import("backend.zig").backend.Backend;
pub const Buffer = @import("buffer.zig").Buffer;
pub const Rune = @import("rune.zig").Rune;

pub const Config = struct {
    // TODO
};
pub const SupportedFeatures = struct {
    // TODO
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
    allocator: *std.mem.allocator,
    key_callbacks: std.ArrayList(event.key.Callback),
    mouse_callbacks: std.ArrayList(event.mouse.Callback),
    screen_size: Size,
    screen_buffer: Buffer,
    backend: Backend,

    const Self = @This();

    /// This function should be called *after* declaring a `Termelot` struct:
    ///     var termelot: Termelot = undefined;        OR
    ///     var termelot = @as(Termelot, undefined);
    pub fn init(
        self: *Self,
        allocator: *std.mem.allocator,
        config: Config,
        initial_buffer_size: ?Size,
    ) !void {
        self.backend = try Backend.init(self, allocator, config);
        errdefer self.backend.deinit();
        self.config = config;
        self.supported_features = self.backend.getSupportedFeatures();
        self.key_callbacks = std.ArrayList(event.key.Callback).init(allocator);
        errdefer self.key_callbacks.deinit();
        self.mouse_callbacks = std.ArrayList(event.mouse.Callback).init(allocator);
        errdefer self.mouse_callbacks.deinit();
        self.screen_size = try result.backend.getScreenSize();
        self.screen_buffer = try Buffer.init(
            &self.backend,
            allocator,
            initial_buffer_size,
        );
        errdefer result.screen_buffer.deinit();

        try self.backend.start();
        return result;
    }

    pub fn deinit(self: *Self) void {
        self.backend.stop();
        self.screen_buffer.deinit();
        self.backend.deinit();
        self.key_callbacks.deinit();
        self.mouse_callbacks.deinit();
    }

    /// Set the Termelot-aware screen size. This does NOT resize the physical
    /// terminal screen, and should not be called by users in most cases. This
    /// is intended for use primarily by the backend.
    pub fn setScreenSize(self: *Self, screen_size: Size) void {
        self.screen_size = screen_size;
    }

    pub fn callKeyCallbacks(self: Self) void {}
    pub fn registerKeyCallback(
        self: *Self,
        key_callback: event.key.Callback,
    ) !void {
        for (self.key_callbacks.items) |callback| {
            if (std.meta.eql(callback, key_callback)) {
                return;
            }
        }
        try self.key_callbacks.append(key_callback);
    }
    pub fn deregisterKeyCallback(
        self: *Self,
        key_callback: event.key.Callback,
    ) void {
        var remove_index: usize = self.key_callbacks.items.len;
        for (self.key_callbacks.items) |callback, index| {
            if (std.meta.eql(callback, key_callback)) {
                remove_index = index;
                break;
            }
        }
        if (remove_index < self.key_callbacks.items.len) {
            _ = self.key_callbacks.orderedRemove(remove_index);
        }
    }

    pub fn callMouseCallbacks(self: Self) void {}
    pub fn registerMouseCallback(
        self: *Self,
        mouse_callback: event.mouse.Callback,
    ) !void {
        for (self.mouse_callbacks.items) |callback| {
            if (std.meta.eql(callback, mouse_callback)) {
                return;
            }
        }
        try self.mouse_callbacks.append(mouse_callback);
    }
    pub fn deregisterMouseCallback(
        self: *Self,
        mouse_callback: event.mouse.Callback,
    ) void {
        var remove_index: usize = self.mouse_callbacks.items.len;
        for (self.mouse_callbacks.items) |callback, index| {
            if (std.meta.eql(callback, mouse_callback)) {
                remove_index = index;
                break;
            }
        }
        if (remove_index < self.mouse_callbacks.items.len) {
            _ = self.mouse_callbacks.orderedRemove(remove_index);
        }
    }
};
