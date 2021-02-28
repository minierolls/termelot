// Copyright (c) 2020 Termelot Contributors.

// SPDX-License-Identifier: MIT
// This file is part of the Termelot project under the MIT license.

const std = @import("std");

const termelot = @import("termelot");
usingnamespace termelot.style;
const Rune = termelot.Rune;
const Position = termelot.Position;
const Cell = termelot.Cell;

var running: bool = true;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const config = termelot.Config{
        .raw_mode = true,
        .alternate_screen = true,
    };

    // Initialize Termelot
    var term: termelot.Termelot = undefined;
    try term.init(&gpa.allocator, config, null);
    defer _ = term.deinit();

    try term.setCursorVisibility(false); // Hide the cursor

    const default_style = Style{
        .fg_color = Color.named(.White),
        .bg_color = Color.named(.Black),
        .decorations = Decorations{
            .bold = false,
            .italic = false,
            .underline = false,
            .blinking = false,
        },
    };

    // Rune color overrides for the castle art
    const castle_color_pairs = [_]ColorPair{
        .{ .rune = 'm', .color = Color.named(.BrightBlack) },
        .{ .rune = '>', .color = Color.named(.Red) },
    };

    // ... overrides for text logo
    const text_logo_color_pairs = [_]ColorPair{
        .{ .rune = '\"', .color = Color.named(.BrightBlack) },
        .{ .rune = '`', .color = Color.named(.Red) },
        .{ .rune = '\'', .color = Color.named(.Red) },
        .{ .rune = '.', .color = Color.named(.Red) },
        .{ .rune = 'L', .color = Color.named(.Red) },
        .{ .rune = 'd', .color = Color.named(.Red) },
    };

    // Override the style the internal buffer uses to draw clear cells
    term.screen_buffer.default_style = default_style;

    var text_pos = SignedPos{ .row = -15, .col = 29 };
    var text_target_row: i32 = 21;

    var last_frame_time = std.time.milliTimestamp();
    while (running) {
        const this_frame_time = std.time.milliTimestamp();
        const delta = this_frame_time - last_frame_time; // ms between render calls

        // Clear Termelot's internal screen buffer
        term.screen_buffer.clear();

        // Render ascii to internal screen buffer
        renderAscii(&term, SignedPos{ .col = 0, .row = 10 }, default_style, castle_string[0..], castle_color_pairs[0..]);
        renderAscii(&term, text_pos, default_style, text_logo_string[0..], text_logo_color_pairs[0..]);

        // Make draw call, rendering internal buffer to terminal
        try term.drawScreen();

        // Update
        if (text_pos.row != text_target_row) {
            text_pos.row += 1;
        } else { // Text falldown completed...

        }

        // Sleep 50 milliseconds after frames (to keep computer calm)
        std.time.sleep(50 * std.time.ns_per_ms);

        last_frame_time = this_frame_time;
    }
}

/// Termelot offers a Position, which is a struct of two unsigned 16-bit integers for
/// console interactions. Unsigned integers make sense in the console, but if we want
/// to have anything moving in or out of the screen, we need signed positions.
const SignedPos = struct {
    row: i32,
    col: i32,
};

/// Overrides the color for a rune in the renderAscii function.
const ColorPair = struct {
    rune: Rune,
    color: Color,
};

/// Draw a string `slice` starting at `draw_pos`, with default style `style`.
fn renderAscii(term: *termelot.Termelot, draw_pos: SignedPos, style: Style, slice: []const u8, color_pairs: ?[]const ColorPair) void {
    var pos = draw_pos;
    var i: usize = 0;
    while (i < slice.len) : (i += 1) {
        const c = slice[i];
        if (c == 0) break; 
        if (c == '\n') {
            pos.col = draw_pos.col;
            pos.row += 1;
            continue;
        }
        // Skip out of bounds chars (see SignedPos)
        if (pos.row < 0 or pos.col < 0) continue;
        
        if (c == '0') {
            // Don't modify cell here
        } else {
            // Get any overriden color for the current rune
            var fg = style.fg_color;
            if (color_pairs) |pairs| {
                for (pairs) |pair| {
                    if (pair.rune == c) {
                        fg = pair.color;
                        break;
                    }
                }
            }

            term.setCell(
                Position { .row = @intCast(u16, pos.row), .col = @intCast(u16, pos.col) },
                Cell {
                    .rune = c,
                    .style = Style{
                        .fg_color = fg,
                        .bg_color = style.bg_color,
                        .decorations = style.decorations,
                    },
                },
            );
        }

        pos.col += 1;
    }
}

// Zeros in an ascii art string in this program are interpreted as transparency.
const text_logo_string =
    \\                0000000000000000000000000000000000000000000   ,,  00000000000    0000
    \\  MMP""MM""YMM   00000000000000000000000000000000000000000  `7MM   000000000  mm  000
    \\  P'   MM   `7                                                MM              MM    0
    \\       MM       .gP"Ya  `7Mb,op8 `7MMpMMMb.pMMMb.   .gP"Ya    MM   ,pW"Wq.  mmMMmm  0
    \\       MM      ,M'   Yb   MM' "'   MM    MM    MM  ,M'   Yb   MM  6W'   `Wb   MM     
    \\       MM      8M""""""   MM       MM    MM    MM  8M""""""   MM  8M     M8   MM     
    \\       MM      YM.    ,   MM       MM    MM    MM  YM.    ,   MM  YA.   ,A9   Mb     
    \\     .JMML.     `Mbmmd' .JMML.   .JMML  JMML  JMML. `Mbmmd' .JMML. `Ybmd9'    `Mbmo  
    \\                                                                                     
;

const castle_string =
    \\                                                                                                                      `-:: ::`
    \\                                                  ...   ... .+o/`oo+.          ...   ...,  ...,                        syyy+hd/  ...    ...   ...
    \\     ,...sh.    :/oo+`:                    ..  .+syy: :yyy-/yhhydddo  ```  `.s hy/ -yyyo .yyyy+. ---,                 shhhdddo-://++` -sooso-./:-
    \\ .-`ossyyhd:sssshhhhhyh.                  +yh-.yoyhhs/ohhhoshdhddddh` yyy -yyy dhysyhhhhyydhhdds.yhh+                 +yhyyhmhhyyyhd/-+dddddo+ddh+
    \\.sy:yyyhhddsdhhhdddhhdhy/-`               oyhyyhsyhhdhhhhhhhhhhhddmd +dddosddy hhhdhhddhhddhyhdmhhhho                 /yysyhmdhyyyhhddhhhhdddmdddy
    \\.oyysyyyhhhhhhhhhhddddhhhd+               oyhhhyoyhhddhdddhdddyhhdmm ddddddhhy yddmhdmmhdmdhhddmdhhho                 +yysyyhhhhhhhhhhhhhhddddddds
    \\.sssssyyyhhhhhhhhdddddhdddo               +yydmdsydmmmdmmmdNmmhddmm mdddddhddhy mmmddmmhdmmdddmyymddo                 ohyysyssssyyyyyyyhhhhhhhddd+
    \\ osssyyyhhhhhhhhddddddhdhhs               `mmddddydddhhddddmmdddmm mmm.""""".dhd ddhdhhhdddhhmNyymmm.                 +hssssssssysyhyyhhhhddddddd/
    \\ osssyyyhhhhhhhhdddddddddh+   .:--:-       `mmmmMmmmmmddmmmmdmmmm mmm'mdddddd'dyy mymmmhdmmyymmmdmm                   -hssssssyyssyyhhhhhdddddddd/
    \\`ss syyyyhhhhhhdddddddddddo `-+hyhh+        /yyyyyyyhdyyhyyhhhyhm mm|ddddddddd|yy syyyyhdyyyymmmdd+       |>     .++o +dyyyyyydyyyyhhhhhhhhdddd h/
    \\`ss syyyyyyhhhhdhdddddddddh /yyyhhh:        /yyhhyyyhdyyhyyhhhyhm mm|ddddddddd|yy yysssyhyyyymmddh+       |      -syh ydyyyyyydsyyyhhhhhhhhhdhd h/
    \\`sssssyyyyyhhhhhddddddddddd hhyyhhh:        /yyhhyyyydhyhyyhhhyhm mm|ddddddddh|hy hyysssyyyyymmddds://-```|      -yhd ddyyyyyyhhyyyyhhhhhhhhhhhhh/
    \\`oosssyyyyyhhhhhddddddddddd hysyhhh+``   ```/yyyhyhyyhhhhhyhhhyhm mm|dmmdddddh|hy hhsyysyyyyymmdddd ddssyy+. `---/+yd hdyyyyyyy yyyhhhhhhhhhddhhh:
    \\`ooossyyyyyhhhhhdddddddddmm dddhhhhhyy/ /ss yyyhhyhhyyyyhhyhhhyhm mm|ddmdddddh|hy hhyyyyyyhyymmdddd dmssdhdh-ohhdh+yd ddyyyyyyy yyyyyyyyhhhhhhhhh-
    \\`ooossyyyyyhhhhhhdddddddmmm ddddddhhhhhshhh hhhhyyhhyyhhdhyhhhyhm mm|ddddddddd|yy hhyyyyyyhyymmdddd ddddddddhdhhddddh ddhyyyyyyyyyyyyyyhhhhhhhhhh-
    \\`+osssyyyyhyhhhhddhhd ddmmm dddddddhhhddddh hhhhyyhyyyyhhhddhdhhm mm|ddNdddddh|hy hhyhyyhyhyymmdddddddddmmddddhhhhdhh ddhyyyyyyyyyyyyyyyhhhhhhhhh-
    \\ +ossssyyyyyyhhhhhhdd ddmmm ddhhhhhhhhhhhhhdhyyyyyyyyyyhdhdmhhhhm mm|ddNddddhh|yy hyyyyyddhyymmdddddddddddhddhhhhhhhh hhhhyyyyyyyyyyyyyyyyymhhhhh-
    \\ oosssyyyyyyhhhhddddddddmmm ddhhhhhhhhhhhhhhhhhyyhyyyyhhdhddhdhhm mm|ddmmdddhh|dh dhyhhyhhhyymmmddddddddddddddddddhdh ddhhyyyysyyyyyyyy yyymhhh h-
    \\ +osssyyyyyyhhhhddd dddmmmm dddddhhhhhddddddhhhyyhhyyyhhddhdddhhm mm|ddddddddd|mm mmyhhyhyhyymmmmddmddmdddddddddddddh ddhhyyyyysyysyyyy yyhddhh h:
    \\ +s ssyyyhhhhhhhddd dddmmmm mddddhhhdhddhhddhyyyyyhyyhhhddhhdhhhm dd|ddhddhddh|mm mmhhhyhyhyymmmdddmddddddddddddhhddh mdhhyyysyyssyssyy yhhhhhhhho
    \\ +o ssyyyyhhhhhhddd ddmmmmm ddddddhdddhdhhhhhyyyyyhhyyyhddhhdhhhm dd|dddddddhh|mN mNhhhyyyhyymmmddmmddmmmmddddhhhhhhh ddhhhyyyyyyyyyyyy yyyhhhhhh/
    \\ osssyyyyyhhhhhdddd dddmmmm ddddhdhdddhhhhhhhyyyyyhyyyhhddhdddhdm dddd'''''''hhmm mmmhhyyyhyymmddddmmdddmmdddhhhhhhhh ddhhhyyyyyyysyyyyyyyyhhhhhh/
    \\ oysssyyyyyyhhhmdddddddmmmm dddhhdhhdhhhhhhhhyhyyyhyyyhhddhhhdhhm ddm NNNmmdd hdm mmdhyhyhhyydmdddddddddmmddhhhhhhhhy ddhhyhyyhyyysyyyyyyyyhhhhhh/
    \\ oyssyyyyyyyhhhmdddddddmmmm mddhhhhhdhhhmhhhyyyyyyhyyyhhddhhddhhm mm mNNNNmmhh hm mdhyhhyyhyydmddddddddmmmdddhhhhhhhh dhhhhyyhmssyysssyyyyyyhyyhh/
    \\ osssyyyyyyyhhhddddddddmmmm ddhhhhhhhhhhmhhhyyyyyyhyyhhdddhhhdhdm mm mmmmmmdhh hm mdhhhhyhhyydmdddddddmmmmddhhhhhhhhh hhhhhyyhdssssyyyyyyyyhhyhhh/
    \\ osssyyyyyyhhhhhhhdddddmmmm mdhhhhhhhhhhdhhhyyyyyhhyhhhhhdhhhdhdm mm mmmmmmmhh hd mddhhyhyyyhdmdddddddddmmdddhhhhyyhy ddhyhyyhhyssyyyyyyyyyhhhhhh/
    \\ ossyyyyyyyyyyyhhhhdddddmmm mdhhhhhhhhhhhhhhhyyyyyhhhhhhhdhdddhhm mm mmmmmmmhh hd mmdhhydyhhhdmdddddddddddddddhhhhhhy ddhhhyyyyysyssyyyyyyhyhhhhh/
    \\ ossyyyyyyyyyyhhhhhhhhddmmm ddddhhhhhhhhdhhhhyyyhyhyyyhdddhdddhdm mm mmmmmmmhh hd mmdhhddhhhhddddddmddddddddddddhhhhh ddhyyyyyyssssssyyyyyyhhhhhh/
    \\ osyyyyyhhyyhhhhhhhhhdddmmm dddddddhhhdhhhhhhhhhhhhhhhhhddhhhhhdm mm ddddddddh dd mmdddhhhhddmdddddmmmddddddhhhhhhhhd ddhyyyysssssssssyyyyyhhhhhhs
    \\ ::::::///:::/:::///////+/////////////////////////::://////shhhhyyhysyyyyyyhdmdhhdmmmmy:---::::::::::-..````````````````...........`..............
    \\                                                             .:```     ```````:+++/:/++-
;
