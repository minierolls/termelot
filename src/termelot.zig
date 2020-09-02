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

pub const KeyCallback = struct {
    // TODO
};

pub const MouseCallback = struct {
    // TODO
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

    pub fn init(
        allocator: *std.mem.allocator,
        config: Config,
        initial_buffer_size: ?Size,
    ) !Termelot {
        var result = Termelot{
            .config = config,
            .supported_features = undefined,
            .key_callbacks = std.ArrayList(KeyCallback).init(allocator),
            .mouse_callbacks = std.ArrayList(MouseCallback).init(allocator),
            .screen_size = undefined,
            .screen_buffer = undefined,
            .backend = try Backend.init(allocator, config),
        };
        errdefer result.backend.deinit();

        result.supported_features = result.backend.getSupportedFeatures();
        // TODO: Fill initial screen size
        // TODO: Instead of passing backend pointer, consider getting parent
        //       pointer -> backend from inside the buffer struct.
        result.screen_buffer = try Buffer.init(
            &result.backend,
            allocator,
            initial_buffer_size,
        );
        errdefer result.screen_buffer.deinit();

        //TODO: Fill backend mainloop parameters
        try self.backend.start();

        return result;
    }

    pub fn deinit(self: *Self) void {
        self.backend.stop();
        self.screen_buffer.deinit();
        self.backend.deinit();
    }

    // TODO: Wrap and expose buffer functions here
};
