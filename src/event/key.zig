// Copyright (c) 2020 Termelot Contributors.

// SPDX-License-Identifier: MIT
// This file is part of the Termelot project under the MIT license.

const termelot = @import("../termelot.zig");
const Rune = termelot.Rune;

pub const Callback = struct {
    context: *Context,
    callback: fn (*Context, Event) void,

    const Self = @This();
    const Context = @Type(.Opaque);

    pub fn call(self: Self, event: Event) void {
        self.callback(self.context, event);
    }
};

pub const Event = struct {
    value: Value,
    modifier: ?Modifier,
};

pub const Value = union(ValueType) {
    AlphaNumeric: Rune,
    Function: ValueFunction,
    Navigation: ValueNavigation,
    Edit: ValueEdit,
};

pub const ValueType = enum {
    AlphaNumeric,
    Function,
    Navigation,
    Edit,
};

pub const Modifier = enum {
    Shift,
    Control,
    Alternate,
    AlternateGraphic,
    Meta,
    Function,
};

pub const ValueFunction = enum {
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

pub const ValueNavigation = enum {
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

pub const ValueEdit = enum {
    Backspace,
    Insert,
    Delete,
};
