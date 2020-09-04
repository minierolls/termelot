// Copyright (c) 2020 Termelot Contributors.

// SPDX-License-Identifier: MIT
// This file is part of the Termelot project under the MIT license.

//! Ziro is a super-simple terminal text editor written in Zig.
//! Ziro is inspired by [kilo](https://github.com/antirez/kilo),
//! and is intended to provide an example of using the Termelot
//! library.

const std = @import("std");

const termelot = @import("termelot");
const style = termelot.style;
const event = termelot.event;

const Rune = termelot.Rune;
const Position = termelot.Position;
const Cell = termelot.Cell;
const Style = style.Style;
const Color = style.Color;
const ColorBit8 = style.ColorBit8;
const Decorations = style.Decorations;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const config = termelot.Config{
        // .raw_mode = true,
        // .alternate_screen = true,
    };

    var term: termelot.Termelot = undefined;
    try term.init(&gpa.allocator, config, null);
    defer _ = term.deinit();

    term.setCell(
        Position{ .row = 0, .col = 0 },
        Cell{
            .rune = 'X',
            .style = Style{
                .fg_color = Color{ .Bit8 = ColorBit8{ .code = 148 } },
                .bg_color = Color{ .Bit8 = ColorBit8{ .code = 197 } },
                .decorations = Decorations{
                    .italic = false,
                    .bold = true,
                    .underline = false,
                    .blinking = false,
                },
            },
        },
    );
    term.setCell(
        Position{ .row = 0, .col = 1 },
        Cell{
            .rune = 'X',
            .style = term.screen_buffer.default_style,
        },
    );
    try term.drawScreen();
}
