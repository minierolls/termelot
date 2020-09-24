// Copyright (c) 2020 Termelot Contributors.

// SPDX-License-Identifier: MIT
// This file is part of the Termelot project under the MIT license.

const termelot = @import("termelot.zig");
const Position = termelot.Position;
const Rune = termelot.Rune;
const Size = termelot.Size;

/// A self-contained Event handler. The i64 parameter is for thread synchronization,
/// and it is milliseconds since Unix Epoch. The callback function will be executed
/// from a secondary thread when handling events. The time parameter is provided for
/// synchronization. It is up to the user to prevent data races if the callback modifies
/// shared state through its context.
///
/// **context**: A pointer-as-an-int to a resource accessed by the callback function.
/// the function needs to know about when called.
/// **callback**: The function that will be handling events.
pub const EventCallback = struct {
    context: usize,
    callback: fn (usize, Event, i64) void,

    const Self = @This();

    /// Call the callback function.
    /// **time**: Milliseconds since Unix Epoch.
    pub fn call(self: Self, event: Event, time: i64) void {
        self.callback(self.context, event, time);
    }
};

/// An Event can be a KeyEvent, MouseEvent, or a new terminal size.
/// You can switch on an Event to get its type:
/// ```zig
/// switch (event) {
///     .Key => |key_event| ...
///     .Mouse => |mouse_event| ...
///     .Resize => |new_size| ...
/// }
/// ```
pub const Event = union(EventType) {
    Key: KeyEvent,
    Mouse: MouseEvent,
    Resize: Size,
};

pub const EventType = enum {
    Key,
    Mouse,
    Resize,
};

/// A KeyEvent is an event triggered by a key press or release.
///
/// **value**: The key that has been pressed.
/// **state**: Whether the key event is for key up or key down.
/// **modifier**: One or several modifier keys that were held when the key was pressed.
/// **repeated**: Applies to non-raw mode, where keys can be held down to be repeated.
/// When this field is true, this is a repeat of an earlier KeyEvent. KeyState is always
/// `Down` when a key is a repeat.
pub const KeyEvent = struct {
    value: KeyValue,
    state: KeyState,
    modifier: KeyModifier,
    repeated: bool,
};

/// The Rune field is used when a key is alphanumerical: a-zA-Z, 0-9, and other character
/// keys present on the keyboard. Some special characters like Tab ('\t') and space (' ')
/// will be a Rune value. F1-F12 are found in the Function field. Home, ScrollUp, ScrollDown,
/// Backspace, Return, and more are found in the Control field.
pub const KeyValue = union(KeyType) {
    Rune: Rune,
    Function: KeyFunction,
    Control: KeyControl,
};

pub const KeyType = enum {
    Rune,
    Function,
    Control,
};

/// A modifier is a key that has been held when another key is pressed or a mouse
/// event has occurred. This enum is a bitfield, so none, one, or any number of
/// these fields can be selected in the same enum.
/// ```zig
/// if (modifier & Modifier.Alt > 0 or modifier & Modifier.RightAlt > 0) {
///     // An alt key has been pressed ...
/// } else if (modifier == 0) {
///     // No modifier key was pressed
/// }
/// ```
pub const KeyModifier = enum(u7) {
    Shift = 0b1,
    Alt = 0b10,
    RightAlt = 0b100,
    Ctrl = 0b1000,
    RightCtrl = 0b10000,
    Meta = 0b100000,
    Function = 0b1000000,
    _,
};

/// **Down**: The key has just been pressed and has not been released yet.
/// **Released**: The key was pressed earlier and has just been released.
pub const KeyState = enum {
    Down,
    Released,
};

/// A function key F1-F12.
pub const KeyFunction = enum {
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

pub const KeyControl = enum {
    Backspace,
    Delete,
    Return,
    Escape,
    Home,
    End,
    PageUp,
    PageDown,
    Up,
    Down,
    Left,
    Right,
};

/// An event triggered by a mouse button or scroll wheel.
///
/// **position**: The mouse position in the terminal.
/// **action**: Whether the event was triggered by a Click, scroll, or other means.
/// **button**: If the action is a Click or DoubleClick, which mouse button was used.
pub const MouseEvent = struct {
    position: Position,
    action: MouseAction,
    button: ?MouseButton,
    modifier: KeyModifier,
};

pub const MouseAction = enum {
    Click,
    DoubleClick,
    TripleClick,
    ScrollUp,
    ScrollDown,
    HScrollLeft, // Pushing scroll wheel to the left
    HScrollRight, // ... or right
};

pub const MouseButton = enum {
    Primary, // Left click
    Secondary, // Right click
    Auxiliary, // Scroll wheel click
    Fourth, // The rest are loosely defined ...
    Fifth,
    Sixth,
    Seventh,
    Eighth,
};
