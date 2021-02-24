// Copyright (c) 2020 Termelot Contributors.

// SPDX-License-Identifier: MIT
// This file is part of the Termelot project under the MIT license.

const std = @import("std");

pub const Style = struct {
    fg_color: Color,
    bg_color: Color,
    decorations: Decorations,

    pub fn default() Style {
        return Style{
            .fg_color = Color.Default,
            .bg_color = Color.Default,
            .decorations = Decorations{
                .bold = false,
                .italic = false,
                .underline = false,
                .blinking = false,
            },
        };
    }
};

pub const Decorations = packed struct {
    bold: bool,
    italic: bool,
    underline: bool,
    blinking: bool,

    pub fn none() Decorations {
        return Decorations{
            .bold = false,
            .italic = false,
            .underline = false,
            .blinking = false,
        };
    }
};

pub const Color = union(ColorType) {
    Default: u0,
    Named16: ColorNamed16,
    Bit8: ColorBit8,
    Bit24: ColorBit24,

    /// Create a new Color from red, green, and blue values with a ColorBit24.
    pub inline fn RGB(red: u8, green: u8, blue: u8) Color {
        return Color{ .Bit24 = ColorBit24.initRGB(red, green, blue) };
    }

    /// Create a new Color from a hex code with a ColorBit24.
    pub inline fn hex(code: u24) Color {
        return Color{ .Bit24 = ColorBit24{ .code = code } };
    }

    /// Create a new Color from one of 16 color names with a ColorNamed16.
    pub inline fn named(named: ColorNamed16) Color {
        return Color{ .Named16 = named };
    }
};

pub const ColorType = enum {
    Default,
    Named16,
    Bit8,
    Bit24,
};

/// The first 8 values of the `ColorNamed16` are supported by all colored terminals. Likely anything
/// reasonably capable of being a terminal will support the first 8 values, and probably the other
/// half, as well. These values are only indexes to a palette stored by the terminal -- users may
/// be able to override palettes -- some terminals may do it automatically.
///
/// But in some rare cases, a terminal is only ASCII and will not support colors at all. Hopefully
/// in at least half of these cases, the backend will detect the terminal's ill support of colors,
/// and will ignore any incoming colors. In the event a backend attempts to use colors on a terminal
/// without support for them, that terminal may stop working. But in general, the basic 16 colors
/// are very safe to use, especially on modern terminals.
///
/// Color names and values based on [ANSI Escape Codes](https://en.wikipedia.org/wiki/ANSI_escape_code).
pub const ColorNamed16 = enum {
    Black,
    Red,
    Green,
    Yellow,
    Blue,
    Magenta,
    Cyan,
    White,
    BrightBlack,
    BrightRed,
    BrightGreen,
    BrightYellow,
    BrightBlue,
    BrightMagenta,
    BrightCyan,
    BrightWhite,
};

/// A ColorBit8 is technically an 8-bit reference to a palette containing 24-bit colors.
/// In this library we just refer to it as 8-bit color. Most modern terminals support 256 colors.
///
/// Just like for `ColorBit24`: if 8-bit colors are used on a backend or terminal at runtime that
/// does not support 8-bit color, and the backend knows, then it will round 8-bit colors to
/// `ColorNamed16`s or the highest bit-size color supported.
///
/// Color values based on [ANSI Escape Codes](https://en.wikipedia.org/wiki/ANSI_escape_code).
pub const ColorBit8 = packed struct {
    code: u8,

    /// `ColorNamed16`s comprise the first 16 values of the `ColorBit8`, so the enum is converted
    /// to an integer.
    pub fn fromNamed16(named: ColorNamed16) ColorBit8 {
        return ColorBit8{ .code = @enumToInt(named) };
    }

    pub fn roundToNamed16(self: Self) ColorNamed16 {
        @compileError("unimplemented");
    }
};

/// 16 million color 24-bit, or better known as "True Color" or RGB. Almost an equal number of
/// supporting and non-supporting terminals feature True Color. Some terminals may use rounding
/// to convert 24-bit colors to 8-bit colors, but many more seem not to round, either.
///
/// If 24-bit colors are used on a backend or terminal at runtime that does not support 24-bit color,
/// and the backend knows, then it will round 24-bit colors to the highest bit-size color supported.
/// This rounding may cause differences in appearance: see description of function `roundToBit8`.
///
/// For more information about True Color, see this gist: https://gist.github.com/XVilka/8346728
pub const ColorBit24 = packed struct {
    code: u24,

    const Self = @This();

    pub fn RGB(r: u8, g: u8, b: u8) ColorBit24 {
        var code: u24 = 0;
        code |= b;
        code |= @as(u16, g) << 8;
        code |= @as(u24, r) << 16;
        return ColorBit24{ .code = code };
    }

    pub fn red(self: Self) u8 {
        return @intCast(u8, self.code >> 16);
    }
    pub fn green(self: Self) u8 {
        return @intCast(u8, (self.code >> 8) & 255);
    }
    pub fn blue(self: Self) u8 {
        return @intCast(u8, self.code & 255);
    }

    /// Round 24-bit Color to 8-bit using nearest values. This may be useful when
    /// terminals don't support "True Color" or RGB color. Uses a lookup table to find
    /// nearest 24-bit color equivalents for 8-bit colors on the palette.
    ///
    /// In general, rounding colors to lower bit sizes on terminals cannot be considered
    /// reliable for many reasons. Terminals can use different palettes, and the converted
    /// colors may be nowhere near accurate. But in the same sense, that is true about ColorBit8
    /// already.
    pub fn roundToBit8(self: Self) ColorBit8 {
        const closest_main_idx = binarySearchClosest(&main_table, 0, main_table.len - 1, self.code);
        const closest_grey_idx = binarySearchClosest(&grey_table, 0, grey_table.len - 1, self.code);

        const main_diff = std.math.absInt(@intCast(i32, main_table[closest_main_idx]) - @intCast(i32, self.code)) catch unreachable;
        const grey_diff = std.math.absInt(@intCast(i32, grey_table[closest_grey_idx]) - @intCast(i32, self.code)) catch unreachable;

        if (main_diff < grey_diff) {
            return ColorBit8{ .code = @intCast(u8, closest_main_idx) + 16 };
        } else {
            return ColorBit8{ .code = @intCast(u8, closest_grey_idx) + 232 };
        }
    }
};

/// Binary search sorted `slice` for closest value to `val` between indices `start` and `end`.
/// Returns index to `slice` where closest number is found.
fn binarySearchClosest(slice: []const u24, start: usize, end: usize, val: u24) usize {
    var l = start;
    var r = end;
    var mid: usize = 0;

    while (l <= r) {
        mid = l + (r - l) / 2;
        // NOTE: this binary search does not include the difference in value between selections,
        // so although a number like 0x949493 might be very close to 0x949494, the lower value in
        // the table may be selected instead, because we do not weigh the difference between each
        // whole color. This is better for performance and might not show much difference.

        if (slice[mid] < val) {
            l = mid + 1;
        } else if (slice[mid] > val) {
            r = mid - 1;
        } else {
            return mid; // Found an exact match
        }
    }

    return mid; // Got closest match
}

// Lookup table for standard 16-bit colors after 15, and before 232, as their equivalent 24-bits.
const main_table = [216]u24{
    0x000000, 0x00005f, 0x000087, 0x0000af, 0x0000d7, 0x0000ff,
    0x005f00, 0x005f5f, 0x005f87, 0x005faf, 0x005fd7, 0x005fff,
    0x008700, 0x00875f, 0x008787, 0x0087af, 0x0087d7, 0x0087ff,
    0x00af00, 0x00af5f, 0x00af87, 0x00afaf, 0x00afd7, 0x00afff,
    0x00d700, 0x00d75f, 0x00d787, 0x00d7af, 0x00d7d7, 0x00d7ff,
    0x00ff00, 0x00ff5f, 0x00ff87, 0x00ffaf, 0x00ffd7, 0x00ffff,
    0x5f0000, 0x5f005f, 0x5f0087, 0x5f00af, 0x5f00d7, 0x5f00ff,
    0x5f5f00, 0x5f5f5f, 0x5f5f87, 0x5f5faf, 0x5f5fd7, 0x5f5fff,
    0x5f8700, 0x5f875f, 0x5f8787, 0x5f87af, 0x5f87d7, 0x5f87ff,
    0x5faf00, 0x5faf5f, 0x5faf87, 0x5fafaf, 0x5fafd7, 0x5fafff,
    0x5fd700, 0x5fd75f, 0x5fd787, 0x5fd7af, 0x5fd7d7, 0x5fd7ff,
    0x5fff00, 0x5fff5f, 0x5fff87, 0x5fffaf, 0x5fffd7, 0x5fffff,
    0x870000, 0x87005f, 0x870087, 0x8700af, 0x8700d7, 0x8700ff,
    0x875f00, 0x875f5f, 0x875f87, 0x875faf, 0x875fd7, 0x875fff,
    0x878700, 0x87875f, 0x878787, 0x8787af, 0x8787d7, 0x8787ff,
    0x87af00, 0x87af5f, 0x87af87, 0x87afaf, 0x87afd7, 0x87afff,
    0x87d700, 0x87d75f, 0x87d787, 0x87d7af, 0x87d7d7, 0x87d7ff,
    0x87ff00, 0x87ff5f, 0x87ff87, 0x87ffaf, 0x87ffd7, 0x87ffff,
    0xaf0000, 0xaf005f, 0xaf0087, 0xaf00af, 0xaf00d7, 0xaf00ff,
    0xaf5f00, 0xaf5f5f, 0xaf5f87, 0xaf5faf, 0xaf5fd7, 0xaf5fff,
    0xaf8700, 0xaf875f, 0xaf8787, 0xaf87af, 0xaf87d7, 0xaf87ff,
    0xafaf00, 0xafaf5f, 0xafaf87, 0xafafaf, 0xafafd7, 0xafafff,
    0xafd700, 0xafd75f, 0xafd787, 0xafd7af, 0xafd7d7, 0xafd7ff,
    0xafff00, 0xafff5f, 0xafff87, 0xafffaf, 0xafffd7, 0xafffff,
    0xd70000, 0xd7005f, 0xd70087, 0xd700af, 0xd700d7, 0xd700ff,
    0xd75f00, 0xd75f5f, 0xd75f87, 0xd75faf, 0xd75fd7, 0xd75fff,
    0xd78700, 0xd7875f, 0xd78787, 0xd787af, 0xd787d7, 0xd787ff,
    0xd7af00, 0xd7af5f, 0xd7af87, 0xd7afaf, 0xd7afd7, 0xd7afff,
    0xd7d700, 0xd7d75f, 0xd7d787, 0xd7d7af, 0xd7d7d7, 0xd7d7ff,
    0xd7ff00, 0xd7ff5f, 0xd7ff87, 0xd7ffaf, 0xd7ffd7, 0xd7ffff,
    0xff0000, 0xff005f, 0xff0087, 0xff00af, 0xff00d7, 0xff00ff,
    0xff5f00, 0xff5f5f, 0xff5f87, 0xff5faf, 0xff5fd7, 0xff5fff,
    0xff8700, 0xff875f, 0xff8787, 0xff87af, 0xff87d7, 0xff87ff,
    0xffaf00, 0xffaf5f, 0xffaf87, 0xffafaf, 0xffafd7, 0xffafff,
    0xffd700, 0xffd75f, 0xffd787, 0xffd7af, 0xffd7d7, 0xffd7ff,
    0xffff00, 0xffff5f, 0xffff87, 0xffffaf, 0xffffd7, 0xffffff,
};

// Lookup table for greys as 24-bits.
const grey_table = [24]u24{
    0x080808, 0x121212, 0x1c1c1c, 0x262626, 0x303030, 0x3a3a3a,
    0x444444, 0x4e4e4e, 0x585858, 0x606060, 0x666666, 0x767676,
    0x808080, 0x8a8a8a, 0x949494, 0x9e9e9e, 0xa8a8a8, 0xb2b2b2,
    0xbcbcbc, 0xc6c6c6, 0xd0d0d0, 0xdadada, 0xe4e4e4, 0xeeeeee,
};

// Tables from https://www.calmar.ws/vim/256-xterm-24bit-rgb-color-chart.html

test "roundToBit8" {
    std.testing.expectEqual((ColorBit24 { .code = 0xFFFFFF }).roundToBit8().code, 231); // Index for white
    std.testing.expectEqual((ColorBit24 { .code = 0xFF0000 }).roundToBit8().code, 196); // Index for red
    std.testing.expectEqual((ColorBit24 { .code = 0x949494 }).roundToBit8().code, 246); // Index for some smokey color (grey_table)
    std.testing.expectEqual((ColorBit24 { .code = 0x080808 }).roundToBit8().code, 232); // Index for similar to black (grey_table)
    // NOTE: cannot test rounding because of inaccuracy. See note in binarySearchClosest().
}
