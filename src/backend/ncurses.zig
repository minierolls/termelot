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
const Event = termelot_import.event.Event;

// Zig couldn't translate these macros, I don't blame it:

// #define getyx(win,y,x)		(y = getcury(win), x = getcurx(win))
fn getyx(win: *c.WINDOW) Position {
    return Position{
        .row = @intCast(u16, c.getcury(win)),
        .col = @intCast(u16, c.getcurx(win)),
    };
}

pub const Backend = struct {
    current_window: *c.WINDOW, // should be used in all ncurses function calls
    alternate_window: ?*c.WINDOW,
    in_raw_mode: bool,
    has_color: bool, // Whether this terminal supports colored output
    cursor_visible: bool,

    const Self = @This();

    /// Initialize backend
    pub fn init(
        allocator: *std.mem.Allocator,
        config: Config,
    ) !Backend {
        _ = c.initscr();
        var has_color = false;
        if (c.start_color() == c.OK) {
            has_color = c.has_colors();
            _ = c.use_default_colors(); // color pair -1 is now the terminal default pair
        }

        return Backend{
            .current_window = c.stdscr,
            .alternate_window = null,
            .in_raw_mode = false,
            .has_color = has_color,
            .cursor_visible = true,
        };
    }

    /// Deinitialize backend
    pub fn deinit(self: *Self) void {
        // Reset attributes
        _ = c.attroff(c.COLOR_PAIR(1));
        _ = c.attron(c.A_NORMAL);

        _ = c.endwin();
    }

    /// Retrieve supported features for this backend.
    pub fn getSupportedFeatures(self: *Self) !SupportedFeatures {
        return SupportedFeatures{
            .color_types = .{
                .Named16 = self.has_color,
                .Bit8 = self.has_color and c.COLORS <= 256,
                .Bit24 = self.has_color,
            },
            .decorations = Decorations{
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
        // TODO: how is raw mode disabled supposed to work with pollEvent??
        if (enabled) {
            _ = c.cbreak(); // Disable line-based buffering
            _ = c.noecho(); // Disable echoing user input
            _ = c.nonl(); // Disable enter key generating new-line characters
            _ = c.intrflush(c.stdscr, false); // Prevent flush on interrupts
            _ = c.keypad(c.stdscr, true); // Treat control / arrow / function keys specially??
        } else {
            // TODO: default to the tty driver settings when disabling raw mode
            _ = c.nocbreak(); // Enable line-based buffering
            _ = c.echo(); // Enable echoing user input
            _ = c.nl(); // Enter key generates new-lines "\n"
            _ = c.intrflush(c.stdscr, true);
            _ = c.keypad(c.stdscr, false);
        }
    }

    /// If timeout is less than or equal to zero:
    /// Blocking; return next available Event if one is present, and null otherwise.
    /// If timeout is greater than zero:
    /// Non-blocking; return next available Event if one arises within `timeout` ms.
    pub fn pollEvent(self: *Self, timeout: i32) !?Event {
        // TODO
        return error.Unimplemented;
    }

    /// Retrieve alternate screen status.
    pub fn getAlternateScreen(self: *Self) !bool {
        return self.current_window != c.stdscr;
    }

    /// Enter/exit alternate screen.
    pub fn setAlternateScreen(self: *Self, enabled: bool) !void {
        if (enabled) {
            if (self.alternate_window == null) {
                // TODO: no alt window, we must create one
            }
            // self.current_window = self.alternate_window orelse unreachable;
        } else {
            self.current_window = c.stdscr;
        }
        // TODO
    }

    /// Set terminal title.
    pub fn setTitle(self: *Self, runes: []const Rune) !void {
        // TODO however termios does it
    }

    /// Get screen size.
    pub fn getScreenSize(self: *Self) !Size {
        return Size{
            .rows = @intCast(u16, c.getmaxy(c.stdscr)) + 1,
            .cols = @intCast(u16, c.getmaxx(c.stdscr)) + 1,
        };
    }

    /// Get cursor position.
    pub fn getCursorPosition(self: *Self) !Position {
        return getyx(c.stdscr); // Defined at the top
    }

    /// Set cursor position.
    pub fn setCursorPosition(self: *Self, position: Position) !void {
        _ = c.move(position.row, position.col); // TODO: make sure we can discard this return code
    }

    /// Get cursor visibility.
    pub fn getCursorVisibility(self: *Self) !bool {
        return self.cursor_visible;
    }

    /// Set cursor visibility.
    pub fn setCursorVisibility(self: *Self, visible: bool) !void {
        self.cursor_visible = visible;
        _ = c.curs_set(@intCast(c_int, @boolToInt(visible)));
    }

    /// Parse a Style and using ncurses' attrset, set terminal attributes.
    fn setAttributes(self: *Self, style: *const Style) void {
        // NOTE: use wattr to operate on a specific WINDOW*
        var attr: c_uint = 0;

        if (style.decorations.bold) attr |= c.A_BOLD;
        if (style.decorations.italic) attr |= c.A_ITALIC; // NOTE: A_ITALIC is a feature of 2013's ncurses 5.10.
        if (style.decorations.underline) attr |= c.A_UNDERLINE;
        if (style.decorations.blinking) attr |= c.A_BLINK;

        _ = c.wattrset(c.stdscr, @intCast(c_int, attr));

        // if (!self.has_color) return;

        // NOTE: see description of `man 3 init_pair` about converting pairs to video attributes...

        // default colors
        // TODO: copy colors from pair -1 (terminal defaults) to these attributes (using attr_get)
        var fg_color: c_int = 7; // foreground white
        var bg_color: c_int = 0; // background black

        // TODO: hypothesis is that colors 0-7 are set, and all others are not... lol

        switch (style.fg_color) {
            .Default => {},
            .Named16 => |v| fg_color = @enumToInt(v), // do good
            .Bit8 => |v| fg_color = v.code, // questionable
            .Bit24 => |v| fg_color = v.roundToBit8().code, // uh oh
        }

        switch (style.bg_color) {
            .Default => {},
            .Named16 => |v| bg_color = @enumToInt(v),
            .Bit8 => |v| bg_color = v.code,
            .Bit24 => |v| bg_color = v.roundToBit8().code, // TODO: RGB (probably have to use ANSI escape sequence manually)
        }

        // std.log.debug("{}", .{fg_color});

        // TODO: I believe init-ing pairs resets all colors on the screen with that pair????
        _ = c.init_extended_pair(1, fg_color, bg_color); // we always reassign pair 1
        _ = c.wattr_on(c.stdscr, @intCast(c_uint, c.COLOR_PAIR(1)), c.NULL); // make sure it is set
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
        _ = c.wmove(c.stdscr, position.row, position.col);
        for (runes) |rune, i| {
            // set styling
            self.setAttributes(&styles[i]);
            // write next character
            // TODO: make sure this supports UTF-8
            _ = c.waddch(c.stdscr, rune); // NOTE: addch adds character to window stdscr, use waddch for other c.WINDOW*
        }

        // NOTE: could use wchgat to set character attributes *after* writing characters to optimize styling...

        _ = c.wrefresh(c.stdscr); // Redraw terminal from what we've written to stdscr
    }
};

test "ncurses - refAllDecls" {
    std.testing.refAllDecls(Backend);
}
