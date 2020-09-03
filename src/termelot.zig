// Copyright (c) 2020 Termelot Contributors.

// SPDX-License-Identifier: MIT
// This file is part of the Termelot project under the MIT license.

const std = @import("std");

const backend_import = @import("backend.zig").backend;
const Backend = backend_import.Backend;

const buffer_import = @import("buffer.zig");
const Buffer = buffer_import.Buffer;

const style_import = @import("style.zig");
pub const Style = style_import.Style;
pub const Decorations = style_import.Decorations;
pub const Color = style_import.Color;
pub const ColorType = style_import.ColorType;
pub const ColorNamed16 = style_import.ColorNamed16;
pub const ColorBit8 = style_import.ColorBit8;
pub const ColorBit24 = style_import.ColorBit24;

const rune_import = @import("rune.zig");
pub const Rune = rune_import.Rune;

const event_import = @import("event.zig");

pub const KeyCallback = event_import.KeyCallback;
pub const KeyEvent = event_import.KeyEvent;
pub const KeyValue = event_import.KeyValue;
pub const KeyValueType = event_import.KeyValueType;
pub const KeyModifier = event_import.KeyModifier;
pub const KeyValueFunction = event_import.KeyValueFunction;
pub const KeyValueNavigation = event_import.KeyValueNavigation;
pub const KeyValueEdit = event_import.KeyValueEdit;

pub const MouseCallback = event_import.MouseCallback;
pub const MouseEvent = event_import.MouseEvent;
pub const MouseAction = event_import.MouseAction;
pub const MouseButton = event_import.MouseButton;

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
    key_callbacks: std.ArrayList(KeyCallback),
    mouse_callbacks: std.ArrayList(MouseCallback),
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
        self.key_callbacks = std.ArrayList(KeyCallback).init(allocator);
        errdefer self.key_callbacks.deinit();
        self.mouse_callbacks = std.ArrayList(MouseCallback).init(allocator);
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
        key_callback: KeyCallback,
    ) !void {}
    pub fn deregisterKeyCallback(
        self: *Self,
        key_callback: KeyCallback,
    ) void {}

    pub fn callMouseCallbacks(self: Self) void {}
    pub fn registerMouseCallback(
        self: *Self,
        mouse_callback: MouseCallback,
    ) !void {}
    pub fn deregisterMouseCallback(
        self: *Self,
        mouse_callback: MouseCallback,
    ) void {}

    // TODO: Wrap and expose buffer functions here
};
