// Copyright (c) 2020 Termelot Contributors.
// This file is part of the Termelot project under the MIT license.

pub const Style = struct {
    fg_color: Color,
    bg_color: Color,
    decorations: Decorations,

    const Self = @This();

    pub fn equal(self: Self, other: Style) bool {
        return self.fg_color.equal(other.fg_color) and
            self.bg_color.equal(other.bg_color) and
            self.decorations.equal(other.decorations);
    }
};

pub fn equal(a: Style, b: Style) bool {
    return a.equal(b);
}

pub const Decorations = packed struct {
    bold: bool,
    italic: bool,
    underline: bool,
    blinking: bool,

    const Self = @This();

    pub fn equal(self: Self, other: Decorations) bool {
        return self.bold == other.bold and
            self.italic == other.italic and
            self.underline == other.underline and
            self.blinking == other.blinking;
    }
};

pub const Color = union(ColorType) {
    Default: u0,
    Named16: ColorNamed16,
    Bit8: Bit8,
    Bit24: Bit24,

    const Self = @This();

    pub fn equal(self: Self, other: Color) bool {
        if (@as(ColorType, self) != @as(ColorType, other)) return false;
        return switch (self) {
            ColorType.Default => true,
            ColorType.Named16 => |name| name == other.Named16,
            ColorType.Bit8 => |value| value.code == other.Bit8.code,
            ColorType.Bit24 => |value| value.code == other.Bit24.code,
        };
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

    pub fn initRGB(red: u8, green: u8, blue: u8) ColorBit24 {
        var code: u24 = 0;
        code |= blue;
        code |= @as(u16, green) << 8;
        code |= @as(u24, red) << 16;
        return ColorBit24{ .code = code };
    }

    pub fn red(self: Self) u8 {
        return @intCast(self.code >> 16);
    }
    pub fn green(self: Self) u8 {
        return @intCast((self.code >> 8) & 255);
    }
    pub fn blue(self: Self) u8 {
        return @intCast(self.code & 255);
    }
};
