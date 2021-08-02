// Copyright (c) 2020 Termelot Contributors.

// SPDX-License-Identifier: MIT
// This file is part of the Termelot project under the MIT license.

const c = @cImport({
    @cInclude("sys/ioctl.h");
    @cInclude("sys/time.h");
    @cInclude("termios.h");
});
const builtin = @import("builtin");
const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const stdin = std.io.getStdIn();
const stdout = std.io.getStdOut();

const termelot = @import("../termelot.zig");
usingnamespace termelot.style;
usingnamespace termelot.event;
const BackendName = termelot.backend.BackendName;
const Config = termelot.Config;
const Position = termelot.Position;
const Rune = termelot.Rune;
const Size = termelot.Size;
const SupportedFeatures = termelot.SupportedFeatures;

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
    .linux => switch (std.builtin.cpu.arch) {
        .x86_64 => 6,
        .aarch64 => 6,
        .mipsel => 4,
        else => c.VMIN,
    },
    else => c.VMIN,
};
const VTIME = switch (std.builtin.os.tag) {
    .linux => switch (std.builtin.cpu.arch) {
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
        .linux => return std.os.tcgetattr(fd) catch
            return error.BackendError,
        else => {
            var current_termios: TermiosType = undefined;
            if (c.tcgetattr(fd, &current_termios) < 0) {
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
    allocator: *Allocator,
    alternate: bool,
    cursor_visible: bool,
    cursor_position: Position,
    input_buffer: ArrayList(u8),

    const Self = @This();

    /// The tag of a backend is like its identifier. It is used in the build system, and by users
    /// for comptime code.
    pub const tag = BackendName.termios;

    /// Initialize backend
    pub fn init(
        allocator: *std.mem.Allocator,
        config: Config,
    ) !Backend {
        const orig_termios = try tcgetattr(stdin.handle);
        _ = config;
        var result = Backend{
            .orig_termios = orig_termios,
            .allocator = allocator,
            .alternate = false,
            .cursor_visible = false,
            .cursor_position = undefined,
            .input_buffer = try ArrayList(u8).initCapacity(allocator, 128),
        };

        try result.setCursorPosition(Position{ .row = 0, .col = 0 });

        return result;
    }

    /// Deinitialize backend
    pub fn deinit(self: *Self) void {
        tcsetattr(stdin.handle, self.orig_termios) catch {};
        self.input_buffer.deinit();
    }

    /// Retrieve supported features for this backend.
    pub fn getSupportedFeatures(self: *Self) !SupportedFeatures {
        _ = self;
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
    pub fn getRawMode() !bool {
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

    /// Read `n` bytes from terminal.
    pub fn read_up_to(self: *Self, n: i32) !isize {
        const prev_len = self.input_buffer.items.len;
        self.input_buffer.ensureCapacity(self.input_buffer.capacity + n);

        var read_n = 0;
        while (read_n <= n) {
            var r: isize = 0;
            if (read_n < n) {
                r = c.read(inout, self.input_buffer.items.ptr + prev_len + read_n, n - read_n);
            }

            if (r < 0) {
                std.debug.assert(c.errno != c.EAGAIN and c.errno != c.EWOULDBLOCK);
                return error.Idk; // TODO check man pages
            } else if (r > 0) {
                read_n += r;
            } else {
                // TODO: maybe???
                self.input_buffer.ensureCapacity(prev_len + read_n);
                return read_n;
            }
        }
        unreachable;
    }

    /// If timeout is less than or equal to zero:
    /// Blocking; return next available Event if one is present, and null otherwise.
    /// If timeout is greater than zero:
    /// Non-blocking; return next available Event if one arises within `timeout` ms.
    pub fn pollEvent(self: *Self, timeout: i32) !?Event {
        // Describe the timeout with a timeval in seconds and microseconds.
        const tv = c.timeval{
            .tv_sec = timeout / 1000,
            .tv_usec = (timeout - (tv.tv_sec * 1000)) * 1000,
        };

        var events: c.fd_set = undefined;
        _ = events;
        _ = tv;
        _ = self;

        // Attempt to read an event from the input buffer

        return null; // TODO: replace
    }

    /// Set terminal title.
    pub fn setTitle(self: *Self, runes: []const Rune) !void {
        _ = self;
        _ = try stdout.writer().print("\x1b]0;{s}\x07", .{runes});
    }

    /// Get screen size.
    pub fn getScreenSize(self: *Self) !Size {
        _ = self;
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
