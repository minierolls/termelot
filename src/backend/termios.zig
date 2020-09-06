// Copyright (c) 2020 Termelot Contributors.

// SPDX-License-Identifier: MIT
// This file is part of the Termelot project under the MIT license.

const c = @cImport({
    @cInclude("sys/ioctl.h");
    @cInclude("termios.h");
});

const std = @import("std");
const stdin = std.io.getStdIn();
const stdout = std.io.getStdOut();

const termelot_import = @import("../termelot.zig");
const Termelot = termelot_import.Termelot;
const Config = termelot_import.Config;
const SupportedFeatures = termelot_import.SupportedFeatures;
const Position = termelot_import.Position;
const Size = termelot_import.Size;
const Rune = termelot_import.Rune;
usingnamespace termelot_import.style;

fn ioctl(fd: std.os.fd_t, request: u32, comptime ResT: type) !ResT {
    var res: ResT = undefined;
    while (true) {
        switch (std.os.errno(std.os.system.ioctl(
            fd,
            request,
            @ptrToInt(&res),
        ))) {
            0 => break,
            std.os.EBADF => return error.BadFileDescriptor,
            std.os.EFAULT => unreachable, // Bad pointer param
            std.os.EINVAL => unreachable, // Bad params
            std.os.ENOTTY => return error.RequestDoesNotApply,
            std.os.EINTR => continue,
            else => |err| return std.os.unexpectedErrno(err),
        }
    }
    return res;
}

fn tcflags(comptime itms: anytype) std.os.tcflag_t {
    comptime {
        var res: std.os.tcflag_t = 0;
        for (itms) |itm| res |= @as(
            std.os.tcflag_t,
            @field(std.os, @tagName(itm)),
        );
        return res;
    }
}

const VMIN: usize = switch (std.builtin.os.tag) {
    .linux => switch (std.builtin.arch) {
        .x86_64 => 6,
        .aarch64 => 6,
        .mipsel => 4,
        else => c.VMIN,
    },
    else => c.VMIN,
};
const VTIME = switch (std.builtin.os.tag) {
    .linux => switch (std.builtin.arch) {
        .x86_64 => 5,
        .aarch64 => 5,
        .mipsel => 5,
        else => c.VMIN,
    },
    else => c.VMIN,
};

const TermiosType = switch (std.builtin.os.tag) {
    .linux => std.os.termios,
    else => c.termios,
};
fn makeRaw(current_termios: TermiosType) TermiosType {
    switch (std.builtin.os.tag) {
        .linux => {
            var new_termios = current_termios;
            new_termios.iflag &= ~tcflags(.{
                .IGNBRK,
                .BRKINT,
                .PARMRK,
                .ISTRIP,
                .INLCR,
                .IGNCR,
                .ICRNL,
                .IXON,
            });
            new_termios.oflag &= ~tcflags(.{.OPOST});
            new_termios.lflag &= ~tcflags(.{
                .ECHO,
                .ECHONL,
                .ICANON,
                .ISIG,
                .IEXTEN,
            });
            new_termios.cflag &= ~tcflags(.{ .CSIZE, .PARENB });
            new_termios.cflag |= @as(std.os.tcflag_t, std.os.CS8);
            new_termios.cc[VMIN] = 0;
            new_termios.cc[VTIME] = 1;
            return new_termios;
        },
        else => {
            var new_termios = current_termios;
            c.cfmakeraw(&new_termios);
            new_termios.c_cc[c.VMIN] = 0;
            new_termios.c_cc[c.VTIME] = 1;
            return new_termios;
        },
    }
}
fn tcgetattr(fd: std.os.fd_t) !TermiosType {
    switch (std.builtin.os.tag) {
        .linux => return std.os.tcgetattr(stdin.handle) catch
            return error.BackendError,
        else => {
            var current_termios: TermiosType = undefined;
            if (c.tcgetattr(stdin.handle, &current_termios) < 0) {
                return error.BackendError;
            }
            return current_termios;
        },
    }
}
fn tcsetattr(fd: std.os.fd_t, termios: TermiosType) !void {
    switch (std.builtin.os.tag) {
        .linux => std.os.tcsetattr(fd, std.os.TCSA.NOW, termios) catch
            return error.BackendError,
        else => if (c.tcsetattr(stdin.handle, c.TCSANOW, &termios) < 0) {
            return error.BackendError;
        },
    }
}

// TODO: Use "/dev/tty" if possible, instead of stdout/stdin
pub const Backend = struct {
    orig_termios: switch (std.builtin.os.tag) {
        .linux => std.os.termios,
        else => c.termios,
    },
    alternate: bool,
    cursor_visible: bool,
    cursor_position: Position,

    const Self = @This();

    /// Initialize backend
    pub fn init(
        termelot: *Termelot,
        allocator: *std.mem.Allocator,
        config: Config,
    ) !Backend {
        const orig_termios = try tcgetattr(stdin.handle);

        var result = Backend{
            .orig_termios = orig_termios,
            .alternate = false,
            .cursor_visible = false,
            .cursor_position = undefined,
        };

        try result.setCursorPosition(Position{ .row = 0, .col = 0 });

        return result;
    }

    /// Deinitialize backend
    pub fn deinit(self: *Self) void {
        tcsetattr(stdin.handle, self.orig_termios) catch {};
    }

    /// Retrieve supported features for this backend.
    pub fn getSupportedFeatures(self: *Self) !SupportedFeatures {
        return SupportedFeatures{
            .color_types = .{
                .Named16 = true,
                .Bit8 = true,
                .Bit24 = true,
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
        const current_termios = try tcgetattr(stdin.handle);

        const new_termios = makeRaw(current_termios);

        return std.meta.eql(new_termios, current_termios);
    }

    /// Enter/exit raw mode.
    pub fn setRawMode(self: *Self, enabled: bool) !void {
        var current_termios = try tcgetattr(stdin.handle);

        if (enabled) {
            const new_termios = makeRaw(current_termios);

            try tcsetattr(stdin.handle, new_termios);
        } else {
            // TODO: Check if there is a way to always disable raw mode, even
            //       if original was in raw mode
            try tcsetattr(stdin.handle, self.orig_termios);
        }
    }

    /// Retrieve alternate screen status.
    pub fn getAlternateScreen(self: *Self) !bool {
        return self.alternate;
    }

    /// Enter/exit alternate screen.
    pub fn setAlternateScreen(self: *Self, enabled: bool) !void {
        if (enabled and self.alternate) return;
        if (!enabled and !self.alternate) return;

        if (enabled) {
            _ = try stdout.writer().write("\x1b[?1049h");
            self.alternate = true;
        } else {
            _ = try stdout.writer().write("\x1b[?1049l");
            self.alternate = false;
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

    /// Set terminal title.
    pub fn setTitle(self: *Self, runes: []const Rune) !void {
        _ = try stdout.writer().print("\x1b]0;{}\x07", .{runes});
    }

    /// Get screen size.
    pub fn getScreenSize(self: *Self) !Size {
        switch (std.builtin.os.tag) {
            .linux => {
                const ws = ioctl(
                    stdout.handle,
                    std.os.linux.TIOCGWINSZ,
                    std.os.linux.winsize,
                ) catch return error.BackendError;
                return Size{ .rows = ws.ws_row, .cols = ws.ws_col };
            },
            .freebsd => {
                const ws = ioctl(
                    stdout.handle,
                    std.os.freebsd.TIOCGWINSZ,
                    std.os.freebsd.winsize,
                ) catch return error.BackendError;
                return Size{ .rows = ws.ws_row, .cols = ws.ws_col };
            },
            .netbsd => {
                const ws = ioctl(
                    stdout.handle,
                    std.os.netbsd.TIOCGWINSZ,
                    std.os.netbsd.winsize,
                ) catch return error.BackendError;
                return Size{ .rows = ws.ws_row, .cols = ws.ws_col };
            },
            else => {
                var ws: c.winsize = undefined;

                if (c.ioctl(stdout.handle, c.TIOCGWINSZ, &ws) < 0 or
                    ws.ws_col == 0 or ws.ws_row == 0)
                {
                    return error.BackendError;
                }

                return Size{
                    .rows = ws.ws_row,
                    .cols = ws.ws_col,
                };
            },
        }
    }

    /// Get cursor position.
    pub fn getCursorPosition(self: *Self) !Position {
        // Querying for cursor position is unfortunately not supported on
        // *many* terminals. Instead, we should keep track of our own
        // representation; sadly, this is not robust against external
        // (outside of Termelot) interactions with the terminal.
        return self.cursor_position;
    }

    /// Set cursor position.
    pub fn setCursorPosition(self: *Self, position: Position) !void {
        _ = try stdout.writer().print(
            "\x1b[{};{}H",
            .{ position.row + 1, position.col + 1 },
        );
        self.cursor_position = position;
    }

    /// Get cursor visibility.
    pub fn getCursorVisibility(self: *Self) !bool {
        return self.cursor_visible;
    }

    /// Set cursor visibility.
    pub fn setCursorVisibility(self: *Self, visible: bool) !void {
        if (visible) {
            _ = try stdout.writer().write("\x1b[?25h");
            self.cursor_visible = true;
        } else {
            _ = try stdout.writer().write("\x1b[?25l");
            self.cursor_visible = false;
        }
    }

    fn writeStyle(style: Style) !void {
        const writer = stdout.writer();
        _ = try writer.write("\x1b[0m");

        if (style.decorations.bold) {
            _ = try writer.write("\x1b[1m");
        }
        if (style.decorations.italic) {
            _ = try writer.write("\x1b[3m");
        }
        if (style.decorations.underline) {
            _ = try writer.write("\x1b[4m");
        }
        if (style.decorations.blinking) {
            _ = try writer.write("\x1b[5m");
        }

        switch (style.fg_color) {
            ColorType.Default => {
                _ = try writer.write("\x1b[39m");
            },
            ColorType.Named16 => |v| _ = try writer.write(switch (v) {
                ColorNamed16.Black => "\x1b[30m",
                ColorNamed16.Red => "\x1b[31m",
                ColorNamed16.Green => "\x1b[32m",
                ColorNamed16.Yellow => "\x1b[33m",
                ColorNamed16.Blue => "\x1b[34m",
                ColorNamed16.Magenta => "\x1b[35m",
                ColorNamed16.Cyan => "\x1b[36m",
                ColorNamed16.White => "\x1b[37m",
                ColorNamed16.BrightBlack => "\x1b[90m",
                ColorNamed16.BrightRed => "\x1b[91m",
                ColorNamed16.BrightGreen => "\x1b[92m",
                ColorNamed16.BrightYellow => "\x1b[93m",
                ColorNamed16.BrightBlue => "\x1b[94m",
                ColorNamed16.BrightMagenta => "\x1b[95m",
                ColorNamed16.BrightCyan => "\x1b[96m",
                ColorNamed16.BrightWhite => "\x1b[97m",
            }),
            ColorType.Bit8 => |v| {
                _ = try writer.print("\x1b[38;5;{}m", .{v.code});
            },
            ColorType.Bit24 => |v| {
                _ = try writer.print("\x1b[38;2;{};{};{}m", .{
                    v.red(),
                    v.green(),
                    v.blue(),
                });
            },
        }

        switch (style.bg_color) {
            ColorType.Default => {
                _ = try writer.write("\x1b[49m");
            },
            ColorType.Named16 => |v| _ = try writer.write(switch (v) {
                ColorNamed16.Black => "\x1b[40m",
                ColorNamed16.Red => "\x1b[41m",
                ColorNamed16.Green => "\x1b[42m",
                ColorNamed16.Yellow => "\x1b[43m",
                ColorNamed16.Blue => "\x1b[44m",
                ColorNamed16.Magenta => "\x1b[45m",
                ColorNamed16.Cyan => "\x1b[46m",
                ColorNamed16.White => "\x1b[47m",
                ColorNamed16.BrightBlack => "\x1b[100m",
                ColorNamed16.BrightRed => "\x1b[101m",
                ColorNamed16.BrightGreen => "\x1b[102m",
                ColorNamed16.BrightYellow => "\x1b[103m",
                ColorNamed16.BrightBlue => "\x1b[104m",
                ColorNamed16.BrightMagenta => "\x1b[105m",
                ColorNamed16.BrightCyan => "\x1b[106m",
                ColorNamed16.BrightWhite => "\x1b[107m",
            }),
            ColorType.Bit8 => |v| {
                _ = try writer.print("\x1b[48;5;{}m", .{v.code});
            },
            ColorType.Bit24 => |v| {
                _ = try writer.print("\x1b[48;2;{};{};{}m", .{
                    v.red(),
                    v.green(),
                    v.blue(),
                });
            },
        }
    }

    /// Write styled output to screen at position. Assumed that no newline
    /// or carriage return runes are provided.
    pub fn write(
        self: *Self,
        position: Position,
        runes: []Rune,
        styles: []Style,
    ) !void {
        if (runes.len != styles.len) {
            return error.BackendError;
        }
        if (runes.len == 0) {
            return;
        }

        try self.setCursorPosition(position);

        var orig_style_index: usize = 0;
        try writeStyle(styles[0]);
        for (styles) |style, index| {
            if (!std.meta.eql(styles[orig_style_index], style)) {
                _ = try stdout.writer().write(runes[orig_style_index..index]);
                orig_style_index = index;
                try writeStyle(style);
            }
        }
        _ = try stdout.writer().write(runes[orig_style_index..]);
        _ = try stdout.writer().write("\x1b[0m");
    }
};
