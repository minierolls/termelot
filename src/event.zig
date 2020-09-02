// Copyright (c) 2020 Termelot Contributors.

// SPDX-License-Identifier: MIT
// This file is part of the Termelot project under the MIT license.

const termelot = @import("termelot.zig");
const Position = termelot.Position;

pub const KeyCallback = struct {
    context: *Context,
    callback: fn (*Context, KeyEvent) void,

    const Self = @This();
    const Context = @Type(.Opaque);

    pub fn call(self: Self, event: KeyEvent) void {
        self.callback(self.context, event);
    }
};

pub const KeyEvent = struct {
    value: KeyValue,
    modifier: ?KeyModifier,
};

pub const KeyValue = union(KeyValueType) {
    AlphaNumeric: Rune,
    Function: KeyValueFunction,
    Navigation: KayValueNavigation,
    Edit: KeyValueEdit,
};

pub const KeyValueType = enum {
    AlphaNumeric,
    Function,
    Navigation,
    Edit,
};

pub const KeyModifier = enum {
    Shift,
    Control,
    Alternate,
    AlternateGraphic,
    Meta,
    Function,
};

pub const KeyValueFunction = enum {
    F1,
    F2,
    F3,
    F4,
    F5,
    F6,
    F7,
    F8,
    F9,
    F10,
    F11,
    F12,
};

pub const KeyValueNavigation = enum {
    Escape,
    Home,
    End,
    PageUp,
    PageDown,
    ArrowUp,
    ArrowDown,
    ArrowLeft,
    ArrowRight,
};

pub const KeyValueEdit = enum {
    Backspace,
    Insert,
    Delete,
};

pub const MouseCallback = struct {
    context: *Context,
    callback: fn (*Context, MouseEvent) void,

    const Self = @This();
    const Context = @Type(.Opaque);

    pub fn call(self: Self, event: MouseEvent) void {
        self.callback(self.context, event);
    }
};

pub const MouseEvent = enum {
    position: Position,
    time: u32, // TODO
    action: ?MouseAction,
    button: ?MouseButton,
};

pub const MouseAction = enum {
    ScrollUp,
    ScrollDown,
    Click,
    // DoubleClick, // TODO: Decide whether this should be handled by library or backend
    // TripleClick,
};

pub const MouseButton = enum {
    Main,
    Secondary,
    Auxiliary,
    Fourth,
    Fifth,
    Sixth,
    Seventh,
    Eigth,
};
