// Copyright (c) 2020 Termelot Contributors.
// This file is part of the Termelot project under the MIT license.

const std = @import("std");

const backend_import = @import("backend.zig").backend;
const Backend = backend_import.Backend;

const buffer_import = @import("buffer.zig");
const Buffer = buffer_import.Buffer;

// TODO: Import and re-expose Style definitions
// TODO: Import and re-expose Rune definitions

pub const Config = struct {
    // TODO
};
pub const SupportedFeatures = struct {
    // TODO
};

pub const Size = packed struct {
    rows: u16,
    cols: u16,

    const Self = @This();

    pub fn equal(self: Self, other: Size) bool {
        return self.rows == other.rows and self.cols == other.cols;
    }
};

pub const Position = packed struct {
    row: u16,
    col: u16,

    const Self = @This();

    pub fn equal(self: Self, other: Position) bool {
        return self.row == other.row and self.col == other.col;
    }
};

pub const Cell = struct {
    rune: Rune,
    style: Style,

    const Self = @This();

    pub fn equal(self: Self, other: Cell) bool {
        return rune.equal(self.rune, other.rune) and
            style.equal(self.style, other.style);
    }
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
        // TODO: Fill initial buffer size, maybe from config?
        result.screen_buffer = try Buffer.init(&result.backend, allocator);

        //TODO: Fill backend mainloop parameters
        self.backend.start();

        return result;
    }

    pub fn deinit(self: *Self) void {
        self.backend.stop();
        self.screen_buffer.deinit();
        self.backend.deinit();
    }

    // TODO: Wrap and expose buffer functions here
};
