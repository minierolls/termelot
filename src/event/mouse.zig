// Copyright (c) 2020 Termelot Contributors.

// SPDX-License-Identifier: MIT
// This file is part of the Termelot project under the MIT license.

const termelot = @import("termelot.zig");
const Position = termelot.Position;

pub const Callback = struct {
    context: *Context,
    callback: fn (*Context, Event) void,

    const Self = @This();
    const Context = @Type(.Opaque);

    pub fn call(self: Self, event: Event) void {
        self.callback(self.context, event);
    }
};

pub const Event = enum {
    position: Position,
    time: u32, // TODO
    action: ?Action,
    button: ?Button,
};

pub const Action = enum {
    ScrollUp,
    ScrollDown,
    Click,
    // DoubleClick, // TODO: Decide whether this should be handled by library or backend
    // TripleClick,
};

pub const Button = enum {
    Main,
    Secondary,
    Auxiliary,
    Fourth,
    Fifth,
    Sixth,
    Seventh,
    Eigth,
};
