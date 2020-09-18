// Copyright (c) 2020 Termelot Contributors.

// SPDX-License-Identifier: MIT
// This file is part of the Termelot project under the MIT license.

pub const Style = struct {
    fg_color: Color,
    bg_color: Color,
    decorations: Decorations,
};

pub const Decorations = packed struct {
    bold: bool,
    italic: bool,
    underline: bool,
    blinking: bool,
};

pub const Color = union(ColorType) {
    Default: u0,
    Named16: ColorNamed16,
    Bit8: ColorBit8,
    Bit24: ColorBit24,

    /// Create a new Color from red, green, and blue values with a ColorBit24.
    pub fn RGB(red: u8, green: u8, blue: u8) Color {
        return Color{ .Bit24 = ColorBit24.initRGB(red, green, blue) };
    }

    /// Create a new Color from a hex code with a ColorBit24.
    pub fn hex(code: u24) Color {
        return Color{ .Bit24 = ColorBit24{ .code = code } };
    }

    /// Create a new Color from one of 16 color names with a ColorNamed16.
    pub fn named(color_named: ColorNamed16) Color {
        return Color{ .Named16 = color_named };
    }
};

pub const ColorType = enum {
    Default,
    Named16,
    Bit8,
    Bit24,
};

/// Color names and values based on:
/// [ANSI Escape Codes](https://en.wikipedia.org/wiki/ANSI_escape_code)
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

/// Color values based on:
/// [ANSI Escape Codes](https://en.wikipedia.org/wiki/ANSI_escape_code)
pub const ColorBit8 = packed struct {
    code: u8,

    pub fn fromNamed16(name: ColorNamed16) ColorBit8 {
        return ColorBit8{ .code = @enumToInt(name) };
    }
};

pub const ColorBit24 = packed struct {
    code: u24,

    const Self = @This();

    pub fn init(hex: u24) ColorBit24 {
        return ColorBit24{ .code = hex };
    }

    pub fn initRGB(red_val: u8, green_val: u8, blue_val: u8) ColorBit24 {
        var code: u24 = 0;
        code |= blue_val;
        code |= @as(u16, green_val) << 8;
        code |= @as(u24, red_val) << 16;
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
};
