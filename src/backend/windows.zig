// Copyright (c) 2020 Termelot Contributors.

// SPDX-License-Identifier: MIT
// This file is part of the Termelot project under the MIT license.

const std = @import("std");

const termelot_import = @import("../termelot.zig");
const Termelot = termelot_import.Termelot;
const SupportedFeatures = termelot_import.SupportedFeatures;
const Config = termelot_import.Config;
const Position = termelot_import.Position;
usingnamespace termelot_import.style;
const Size = termelot_import.Size;
const Rune = termelot_import.Rune;

const windows = std.os.windows;

// WINAPI defines not made in standard library as of Zig commit 84d50c892
const COLORREF = windows.DWORD;

const CONSOLE_CURSOR_INFO = extern struct {
    dwSize: windows.DWORD,
    bVisible: windows.BOOL,
};

const CONSOLE_SCREEN_BUFFER_INFOEX = extern struct {
    cbSize: windows.ULONG,
    dwSize: windows.COORD,
    dwCursorPosition: windows.COORD,
    wAttributes: windows.WORD,
    srWindow: windows.SMALL_RECT,
    dwMaximumWindowSize: windows.COORD,
    wPopupAttributes: windows.WORD,
    bFullscreenSupported: windows.BOOL,
    ColorTable: [16]COLORREF,
};

extern "kernel32" fn CreateConsoleScreenBuffer(
    dwDesiredAccess: windows.DWORD,
    dwShareMode: windows.DWORD,
    lpSecurityAttributes: ?*const windows.SECURITY_ATTRIBUTES,
    dwFlags: windows.DWORD,
    lpScreenBufferData: ?windows.LPVOID,
) callconv(.Stdcall) windows.HANDLE;

extern "kernel32" fn GetConsoleCursorInfo(
    hConsoleOutput: windows.HANDLE,
    lpConsoleCursorInfo: *CONSOLE_CURSOR_INFO,
) callconv(.Stdcall) windows.BOOL;

extern "kernel32" fn GetConsoleScreenBufferInfoEx(
    hConsoleOutput: windows.HANDLE,
    lpConsoleScreenBufferInfoEx: *CONSOLE_SCREEN_BUFFER_INFOEX,
) callconv(.Stdcall) windows.BOOL;

extern "kernel32" fn SetConsoleActiveScreenBuffer(
    hConsoleOutput: windows.HANDLE,
) callconv(.Stdcall) windows.BOOL;

extern "kernel32" fn SetConsoleCursorInfo(
    hConsoleOutput: windows.HANDLE,
    lpConsoleCursorInfo: *CONSOLE_CURSOR_INFO,
) callconv(.Stdcall) windows.BOOL;

extern "kernel32" fn SetConsoleScreenBufferInfoEx(
    hConsoleOutput: windows.HANDLE,
    lpConsoleScreenBufferInfoEx: *const CONSOLE_SCREEN_BUFFER_INFOEX,
) callconv(.Stdcall) windows.BOOL;

extern "kernel32" fn SetConsoleMode(
    hConsoleHandle: windows.HANDLE,
    dwMode: windows.DWORD,
) callconv(.Stdcall) windows.BOOL;

extern "kernel32" fn WriteConsoleA(
    hConsoleOutput: windows.HANDLE,
    lpBuffer: *const c_void,
    nNumberOfCharsToWrite: windows.DWORD,
    lpNumberOfCharsWritten: ?windows.LPDWORD,
    lpReserved: ?windows.LPVOID,
) callconv(.Stdcall) windows.BOOL;

const CONSOLE_TEXTMODE_BUFFER: windows.DWORD = 1;

// when hConsoleHandle param is an input handle:
const ENABLE_ECHO_INPUT: windows.DWORD = 0x0004;
const ENABLE_EXTENDED_FLAGS: windows.DWORD = 0x0080;
const ENABLE_INSERT_MODE: windows.DWORD = 0x0020;
const ENABLE_LINE_MODE: windows.DWORD = 0x0002;
const ENABLE_MOUSE_INPUT: windows.DWORD = 0x0010;
const ENABLE_PROCESSED_INPUT: windows.DWORD = 0x0001;
const ENABLE_QUICK_EDIT_MODE: windows.DWORD = 0x0040;
const ENABLE_WINDOW_INPUT: windows.DWORD = 0x0008;
const ENABLE_VIRTUAL_TERMINAL_INPUT: windows.DWORD = 0x0200;

// when hConsoleHandle param is a screen buffer handle:
const ENABLE_PROCESSED_OUTPUT: windows.DWORD = 0x0001;
const ENABLE_WRAP_AT_EOL_OUTPUT: windows.DWORD = 0x0002;
const ENABLE_VIRTUAL_TERMINAL_PROCESSING: windows.DWORD = 0x0004;
const DISABLE_NEWLINE_AUTO_RETURN: windows.DWORD = 0x0008;
const ENABLE_LVB_GRID_WORLDWIDE: windows.DWORD = 0x0010;

pub const Backend = struct {
    h_console_out_main: windows.HANDLE,
    h_console_out_current: windows.HANDLE,
    h_console_out_alt: ?windows.HANDLE,
    h_console_in: windows.HANDLE,
    in_raw_mode: bool,
    restore_console_mode_out: windows.DWORD,
    restore_console_mode_in: windows.DWORD,
    restore_wattributes: windows.WORD,

    const Self = @This();

    /// Initialize backend
    pub fn init(
        termelot: *Termelot,
        allocator: *std.mem.Allocator,
        config: Config,
    ) !Backend {
        // Get console handles
        const out_main = try windows.GetStdHandle(windows.STD_OUTPUT_HANDLE);
        const in_main = try windows.GetStdHandle(windows.STD_INPUT_HANDLE);

        // Set restore values
        var rcm_out: windows.DWORD = undefined;
        if (windows.kernel32.GetConsoleMode(out_main, &rcm_out) == 0) {
            return error.BackendError;
        }
        var rcm_in: windows.DWORD = undefined;
        if (windows.kernel32.GetConsoleMode(in_main, &rcm_in) == 0) {
            return error.BackendError;
        }

        var b = Backend{
            .h_console_out_main = out_main,
            .h_console_out_current = out_main,
            .h_console_in = in_main,
            .h_console_out_alt = null,
            .in_raw_mode = false,
            .restore_console_mode_out = rcm_out,
            .restore_console_mode_in = rcm_in,
            .restore_wattributes = undefined,
        };

        b.restore_wattributes = (try getScreenBufferInfo(&b)).wAttributes;

        return b;
    }

    /// Deinitialize backend
    pub fn deinit(self: *Self) void {
        defer _ = windows.kernel32.CloseHandle(self.h_console_out_main);
        self.setAlternateScreen(false) catch {};
        if (self.h_console_out_alt) |handle| {
            _ = windows.kernel32.CloseHandle(handle);
        }
        // Restore console behavior
        _ = SetConsoleMode(self.h_console_out_main, self.restore_console_mode_out);
        _ = SetConsoleMode(self.h_console_in, self.restore_console_mode_in);
        _ = windows.kernel32.SetConsoleTextAttribute(self.h_console_out_main, self.restore_wattributes);
    }

    /// Retrieve SupportedFeatures struct from this backend.
    pub fn getSupportedFeatures(self: *Self) !SupportedFeatures {
        return SupportedFeatures{
            .color_types = .{
                .Named16 = true,
                .Bit8 = false,
                .Bit24 = true,
            },
            .decorations = Decorations {
                .bold = false,
                .italic = false,
                .underline = false,
                .blinking = false, // TODO: is blinking possible?
            }
        };
    }

    /// Retrieve raw mode status.
    pub fn getRawMode(self: *Self) !bool {
        return self.in_raw_mode;
    }

    /// Enter/exit raw mode.
    pub fn setRawMode(self: *Self, enabled: bool) !void {
        var old_input_flags: windows.DWORD = undefined;
        var input_flags: windows.DWORD = undefined;

        var old_output_flags: windows.DWORD = undefined;
        var output_flags: windows.DWORD = undefined;

        if (enabled) {
            input_flags = ENABLE_EXTENDED_FLAGS |
                ENABLE_MOUSE_INPUT |
                ENABLE_WINDOW_INPUT |
                ENABLE_VIRTUAL_TERMINAL_INPUT;
            output_flags = ENABLE_VIRTUAL_TERMINAL_PROCESSING |
                DISABLE_NEWLINE_AUTO_RETURN;
        } else {
            input_flags = ENABLE_ECHO_INPUT |
                ENABLE_EXTENDED_FLAGS |
                ENABLE_INSERT_MODE |
                ENABLE_LINE_MODE |
                ENABLE_MOUSE_INPUT |
                ENABLE_PROCESSED_INPUT |
                ENABLE_QUICK_EDIT_MODE |
                ENABLE_WINDOW_INPUT |
                ENABLE_VIRTUAL_TERMINAL_INPUT;
            output_flags = ENABLE_PROCESSED_OUTPUT |
                ENABLE_WRAP_AT_EOL_OUTPUT |
                ENABLE_VIRTUAL_TERMINAL_PROCESSING;
        }

        if (windows.kernel32.GetConsoleMode(
            self.h_console_in,
            &old_input_flags,
        ) == 0) {
            return error.BackendError;
        }
        if (SetConsoleMode(self.h_console_in, input_flags) == 0) {
            return error.BackendError;
        }
        errdefer _ = SetConsoleMode(self.h_console_in, old_input_flags);

        if (windows.kernel32.GetConsoleMode(
            self.h_console_out_current,
            &old_output_flags,
        ) == 0) {
            return error.BackendError;
        }
        if (SetConsoleMode(
            self.h_console_out_current,
            output_flags,
        ) == 0) {
            return error.BackendError;
        }
        self.in_raw_mode = enabled;
    }

    /// Retrieve alternate screen status.
    pub fn getAlternateScreen(self: *Self) !bool {
        if (self.h_console_out_alt) |handle| {
            return handle == self.h_console_out_current;
        }
        return false;
    }

    /// Enter/exit alternate screen.
    pub fn setAlternateScreen(self: *Self, enabled: bool) !void {
        if (enabled) {
            if (self.h_console_out_alt == null) {
                self.h_console_out_alt = CreateConsoleScreenBuffer(
                    windows.GENERIC_READ | windows.GENERIC_WRITE,
                    windows.FILE_SHARE_READ | windows.FILE_SHARE_WRITE,
                    null,
                    CONSOLE_TEXTMODE_BUFFER,
                    null,
                );
                errdefer self.h_console_out_alt = null;
                if (self.h_console_out_alt == windows.INVALID_HANDLE_VALUE) {
                    return error.BackendError;
                }
            }
            if (self.h_console_out_alt) |handle| {
                if (SetConsoleActiveScreenBuffer(handle) == 0) {
                    return error.BackendError;
                }
                self.h_console_out_current = handle;
            }
        } else {
            if (SetConsoleActiveScreenBuffer(self.h_console_out_main) == 0) {
                return error.BackendError;
            }
            self.h_console_out_current = self.h_console_out_main;
        }
    }

    /// Start event/signal handling loop, non-blocking immediate return.
    pub fn start(self: *Self) !void {
        // This function should call necessary functions for screen size
        // update, key event callbacks, and mouse event callbacks.
        // @compileError("Unimplemented");
    }

    /// Stop event/signal handling loop.
    pub fn stop(self: *Self) void {
        // @compileError("Unimplemented");
    }

    fn getScreenBufferInfo(
        self: *Self,
    ) !windows.CONSOLE_SCREEN_BUFFER_INFO {
        var csbi: windows.CONSOLE_SCREEN_BUFFER_INFO = undefined;
        if (windows.kernel32.GetConsoleScreenBufferInfo(
            self.h_console_out_current,
            &csbi,
        ) == 0) {
            return error.BackendError;
        }
        return csbi;
    }

    /// Set terminal title.
    pub fn setTitle(self: *Self, runes: []Rune) !void {
        @compileError("Unimplemented");
    }

    /// Get screen size.
    pub fn getScreenSize(self: *Self) !Size {
        const csbi = try self.getScreenBufferInfo();
        return Size{
            .rows = @intCast(
                u16,
                csbi.srWindow.Bottom - csbi.srWindow.Top + 1,
            ),
            .cols = @intCast(
                u16,
                csbi.srWindow.Right - csbi.srWindow.Left + 1,
            ),
        };
    }

    /// Get cursor position.
    pub fn getCursorPosition(self: *Self) !Position {
        const csbi = try self.getScreenBufferInfo();
        return Position{
            .row = @intCast(
                u16,
                csbi.dwCursorPosition.Y - csbi.srWindow.Top,
            ),
            .col = @intCast(
                u16,
                csbi.dwCursorPosition.X - csbi.srWindow.Left,
            ),
        };
    }

    /// Set cursor position.
    pub fn setCursorPosition(self: *Self, position: Position) !void {
        const csbi = try self.getScreenBufferInfo();
        var coord = windows.COORD{
            .Y = @intCast(i16, position.row) + csbi.srWindow.Top,
            .X = @intCast(i16, position.col) + csbi.srWindow.Left,
        };
        if (windows.kernel32.SetConsoleCursorPosition(
            self.h_console_out_current,
            coord,
        ) == 0) {
            return error.BackendError;
        }
    }

    /// Get cursor visibility.
    pub fn getCursorVisibility(self: *Self) !bool {
        var cursor_info: CONSOLE_CURSOR_INFO = undefined;
        if (GetConsoleCursorInfo(
            self.h_console_out_current,
            &cursor_info,
        ) == 0) {
            return error.BackendError;
        }
        return cursor_info.bVisible != 0;
    }

    /// Set cursor visibility.
    pub fn setCursorVisibility(self: *Self, visible: bool) !void {
        const cursor_info = CONSOLE_CURSOR_INFO{
            .dwSize = 100,
            .bVisible = if (visible) 1 else 0,
        };
        if (SetConsoleCursorInfo(
            self.h_console_out_current,
            &cursor_info,
        ) == 0) {
            return error.BackendError;
        }
    }

    /// Get the Windows attribute data for a Named16. Will not handle Named16 Brights.
    fn getAttributeForNamed16IgnoreBright(color: ColorNamed16) windows.WORD {
        return switch (color) {
            .Black, .BrightBlack => 0, // No bits for black :^)
            .Red, .BrightRed => windows.FOREGROUND_RED,
            .Green, .BrightGreen => windows.FOREGROUND_GREEN,
            .Yellow, .BrightYellow => windows.FOREGROUND_RED | windows.FOREGROUND_GREEN,
            .Blue, .BrightBlue => windows.FOREGROUND_BLUE,
            .Magenta, .BrightMagenta => windows.FOREGROUND_RED | windows.FOREGROUND_BLUE,
            .Cyan, .BrightCyan => windows.FOREGROUND_GREEN | windows.FOREGROUND_BLUE,
            .White, .BrightWhite => windows.FOREGROUND_RED | windows.FOREGROUND_GREEN | windows.FOREGROUND_BLUE,
        };
    }

    pub fn setWindowsPaletteColor(self: *Self, idx: usize, color: ColorBit24) !void {
        std.debug.assert(idx >= 0 and idx < 16);

        var csbi_ex: CONSOLE_SCREEN_BUFFER_INFOEX = undefined;
        csbi_ex.cbSize = @sizeOf(CONSOLE_SCREEN_BUFFER_INFOEX);
        if (GetConsoleScreenBufferInfoEx(self.h_console_out_current, &csbi_ex) == 0)
            return error.BackendError;

        csbi_ex.ColorTable[idx] = @intCast(COLORREF, color.code);

        if (SetConsoleScreenBufferInfoEx(self.h_console_out_current, &csbi_ex) == 0)
            return error.BackendError;
    }

    /// Translates the TermCon Style into a Windows console attribute.
    fn getAttribute(self: *Self, style: Style) !windows.WORD {
        if (style.decorations.italic or style.decorations.bold or style.decorations.underline or style.decorations.blinking) {
            return error.BackendError; // Windows console API does not support text decorations, but using ANSI backend on Powershell and other editors on Windows works with text decorations.
        }

        var attr = @as(windows.WORD, 0);

        // Foreground colors
        attr |= switch (style.fg_color) {
            .Default => self.restore_wattributes & 0xF,
            .Named16 => |v| getAttributeForNamed16IgnoreBright(v) | if (v.isBright()) windows.FOREGROUND_INTENSITY else @as(windows.WORD, 0),
            .Bit8 => return error.BackendError,
            .Bit24 => |v| {
                try self.setWindowsPaletteColor(0, v);
                return 0; // no bits for black, which is the palette color we overwrote
            }
        };
        // TODO: when you gotta deal with RGB use this https://stackoverflow.com/questions/9509278/rgb-specific-console-text-color-c

        // Background colors
        attr |= switch (style.fg_color) {
            .Default => self.restore_wattributes & 0xF0,
            .Named16 => |v| (getAttributeForNamed16IgnoreBright(v) | if (v.isBright()) windows.FOREGROUND_INTENSITY else @as(windows.WORD, 0)) << 4,
            .Bit8 => return error.BackendError,
            .Bit24 => |v| {
                try self.setWindowsPaletteColor(0, v);
                return 0; // NOTE: a shift left of 4 is going to be optimized away, but one is thought to be here
            }
        };

        // std.log.debug("attr: {}\n", .{attr});

        return attr;
    }

    /// Write styled output to screen at position. Assumed that no newline
    /// or carriage return runes are provided.
    pub fn write(
        self: *Self,
        position: Position,
        runes: []Rune,
        styles: []Style,
    ) !void {
        std.debug.assert(runes.len == styles.len);

        const csbi = try self.getScreenBufferInfo();
        var coord = windows.COORD{
            .X = @intCast(windows.SHORT, position.col),
            .Y = @intCast(windows.SHORT, position.row),
        };

        // Set new cursor position
        if (windows.kernel32.SetConsoleCursorPosition(self.h_console_out_current, coord) == 0) {
            std.log.emerg("GetLastError() = {}\n", .{windows.kernel32.GetLastError()});
            return error.BackendError;
        }

        var index: u32 = 0;
        while (index < runes.len) : (index += 1) {
            if (index == 0 or !std.meta.eql(styles[index], styles[index - 1])) {
                // Update attributes
                try self.setWindowsPaletteColor(0, ColorBit24 { .code = 0 }); // Set palette position for 'Black' to black
                if (windows.kernel32.SetConsoleTextAttribute(self.h_console_out_current, try self.getAttribute(styles[index])) == 0)
                    return error.BackendError;
            }

            // std.log.debug("len: {}\n", .{runes.len});

            if (WriteConsoleA(self.h_console_out_current, &runes, @intCast(windows.DWORD, runes.len), null, null) == 0)
                return error.BackendError;

            coord.X += 1; // TODO: handle newlines
        }
    }
};
