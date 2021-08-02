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
const ColorNamed16 = style.ColorNamed16;
const Decorations = style.Decorations;

pub fn log(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    termelot.log(level, scope, format, args);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const config = termelot.Config{
        .raw_mode = true,
        .alternate_screen = true,
        .initial_buffer_size = .{ .rows = 800, .cols = 800 },
    };

    var term: termelot.Termelot = undefined;
    term = try term.init(&gpa.allocator, config);
    defer _ = term.deinit();

    term.setCell(
        Position{ .row = 5, .col = 3 },
        Cell{
            .rune = 'X',
            .style = Style{
                .fg_color = Color{ .Named16 = ColorNamed16.BrightRed },
                .bg_color = Color{ .Named16 = ColorNamed16.Blue },
                .decorations = Decorations{
                    .italic = false,
                    .bold = term.supported_features.decorations.bold,
                    .underline = false,
                    .blinking = false,
                },
            },
        },
    );
    // term.setCell(
    //     Position{ .row = 0, .col = 1 },
    //     Cell{
    //         .rune = 'X',
    //         .style = term.screen_buffer.default_style,
    //     },
    // );
    try term.drawScreen();

    std.time.sleep(4 * std.time.ns_per_s);
}
