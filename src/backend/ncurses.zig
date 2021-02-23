// Copyright (c) 2020 Termelot Contributors.

// SPDX-License-Identifier: MIT
// This file is part of the Termelot project under the MIT license.

const c = @cImport({
    @cInclude("ncurses.h");
});

const std = @import("std");

const termelot_import = @import("../termelot.zig");
const Termelot = termelot_import.Termelot;
const Config = termelot_import.Config;
const SupportedFeatures = termelot_import.SupportedFeatures;
const Position = termelot_import.Position;
const Size = termelot_import.Size;
const Rune = termelot_import.Rune;
const Style = termelot_import.style.Style;
const Color = termelot_import.style.Color;
const Decorations = termelot_import.style.Decorations;

pub const Backend = struct {
    const Self = @This();

    in_raw_mode: bool,

    /// Initialize backend
    pub fn init(
        termelot: *Termelot,
        allocator: *std.mem.Allocator,
        config: Config,
    ) !Backend {
        c.initscr();

        if (c.has_colors()) c.start_color();

        return Backend{
            .in_raw_mode = false,
        };
    }

    /// Deinitialize backend
    pub fn deinit(self: *Self) void {
        c.endwin();
    }

    /// Retrieve supported features for this backend.
    pub fn getSupportedFeatures(self: *Self) !SupportedFeatures {
        const has_colors = c.has_colors();
        return SupportedFeatures{
            .color_types = .{
                .Named16 = has_colors,
                .Bit8 = has_colors,
                .Bit24 = has_colors,
            },
            .decorations = Style.Decorations{
                .bold = true,
                .italic = true,
                .underline = true,
                .blinking = true,
            },
        };
    }

    /// Retrieve raw mode status.
    pub fn getRawMode(self: *Self) !bool {
        return self.in_raw_mode;
    }

    /// Enter/exit raw mode.
    pub fn setRawMode(self: *Self, enabled: bool) !void {
        if (enabled) {
            c.cbreak(); // Disable line-based buffering
            c.noecho(); // Disable echoing user input
            c.nonl(); // Disable enter key generating new-line characters
            c.intrflush(c.stdscr, false); // Prevent flush on interrupts
            c.keypad(c.stdscr, true); // Treat control / arrow / function keys specially??
        } else {
            // TODO: default to the tty driver settings when disabling raw mode
            c.nocbreak(); // Enable line-based buffering
            c.echo(); // Enable echoing user input
            c.nl(); // Enter key generates new-lines "\n"
            c.intrflush(c.stdscr, true);
            c.keypad(c.stdscr, false);
        }
    }

    /// If timeout is less than or equal to zero:
    /// Blocking; return next available Event if one is present, and null otherwise.
    /// If timeout is greater than zero:
    /// Non-blocking; return next available Event if one arises within `timeout` ms.
    pub fn pollEvent(self: *Self, timeout: i32) !?Event {
        @compileError("Unimplemented");
    }

    /// Retrieve alternate screen status.
    pub fn getAlternateScreen(self: *Self) !bool {
        @compileError("Unimplemented");
    }

    /// Enter/exit alternate screen.
    pub fn setAlternateScreen(self: *Self, enabled: bool) !void {
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
    pub fn setTitle(self: *Self, runes: []const Rune) !void {
        @compileError("Unimplemented");
    }

    /// Get screen size.
    pub fn getScreenSize(self: *Self) !Size {
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

    /// Parse a Style and using ncurses' attrset, set terminal attributes.
    fn attrset(self: *Self, style: *const Style) !void {
        // NOTE: use wattr to operate on a specific WINDOW*
        var attr: c_short = 0;

        if (style.decorations.bold) attr |= c.A_BOLD;
        if (style.decorations.italic) attr |= c.A_ITALIC; // NOTE: A_ITALIC is a feature of 2013's ncurses 5.10.
        if (style.decorations.underline) attr |= c.A_UNDERLINE;
        if (style.decorations.blinking) attr |= c.A_BLINK;

        const _ = Color;

        // set color pair before use
        switch (style.bg_color) {
            
        }
        // attrset(COLOR_PAIR(1))
    }

    /// Write styled output to screen at position. Assumed that no newline
    /// or carriage return runes are provided.
    pub fn write(
        self: *Self,
        position: Position,
        runes: []Rune,
        styles: []Style,
    ) !void {
        // move to position
        c.move(position.row, position.col);
        for (runes) |rune, i| {
            // set styling
            self.attrset(&styles[i]);
            // write next character
            c.addch(rune); // NOTE: addch adds character to window stdscr, use waddch for other c.WINDOW*
        }

        // NOTE: could use wchgat to set character attributes *after* writing characters to optimize styling...

        c.refresh(); // Redraw terminal from what we've written to stdscr
    }
};

test "ncurses - refAllDecls" {
    std.testing.refAllDecls(Backend);
}
