//! This example is a port of Andy Sloane's donut renderer.
//! https://www.a1k0n.net/2006/09/15/obfuscated-c-donut.html

const std = @import("std");

const termelot = @import("termelot");
const Position = termelot.Position;
const Cell = termelot.Cell;
usingnamespace termelot.style;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const config = termelot.Config{
        .raw_mode = false,
        .alternate_screen = true,
    };

    var term: termelot.Termelot = undefined;
    try term.init(&gpa.allocator, config, null);
    defer term.deinit();

    try term.setCursorVisibility(false);
    defer term.setCursorVisibility(true) catch {};

    try term.setTitle("Termelot Donut");

    const screen_width: f32 = 60.0;
    const screen_height: f32 = 20.0;

    const theta_spacing: f32 = 0.07;
    const phi_spacing: f32 = 0.02;

    const R1: f32 = 1.0;
    const R2: f32 = 2.0;
    const K2: f32 = 5.0;

    const K1: f32 = screen_height * K2 * 3.0 / (8.0 * (R1 + R2));

    var A: f32 = 0.0;
    var B: f32 = 0.0;

    while (true) {
        term.clearScreen();
        A += 0.02;
        B += 0.01;
        const sin_A = std.math.sin(A);
        const cos_A = std.math.cos(A);
        const sin_B = std.math.sin(B);
        const cos_B = std.math.cos(B);

        var theta: f32 = 0.0;
        while (theta < 2.0 * std.math.pi) : (theta += theta_spacing) {
            const sin_theta = std.math.sin(theta);
            const cos_theta = std.math.cos(theta);

            var phi: f32 = 0.0;
            while (phi < 2 * std.math.pi) : (phi += phi_spacing) {
                const sin_phi = std.math.sin(phi);
                const cos_phi = std.math.cos(phi);

                const circle_x = R2 + R1 * cos_theta;
                const circle_y = R1 * sin_theta;

                const x = 2.0 * circle_x *
                    (cos_B * cos_phi + sin_A * sin_B * sin_phi) -
                    circle_y * cos_A * sin_B;
                const y = circle_x *
                    (sin_B * cos_phi - sin_A * cos_B * sin_phi) +
                    circle_y * cos_A * cos_B;
                const z = K2 + cos_A * circle_x * sin_phi + circle_y * sin_A;
                const ooz = 1.0 / z;

                const xp: u16 = @floatToInt(
                    u16,
                    @floor(screen_width / 2 + K1 * ooz * x),
                );
                const yp: u16 = @floatToInt(
                    u16,
                    @floor(screen_height / 2 - K1 * ooz * y),
                );

                const L = cos_phi * cos_theta * sin_B -
                    cos_A * cos_theta * sin_phi -
                    sin_A * sin_theta +
                    cos_B * (cos_A * sin_theta - cos_theta * sin_A * sin_phi);

                if (L > 0.0) {
                    const lum: u8 = @floatToInt(u8, @floor(L * 8.0));
                    var c: Color = undefined;
                    if (lum == 0) {
                        c = Color{ .Bit24 = ColorBit24.initRGB(7, 72, 146) };
                    } else if (lum == 1) {
                        c = Color{ .Bit24 = ColorBit24.initRGB(22, 87, 161) };
                    } else if (lum == 2) {
                        c = Color{ .Bit24 = ColorBit24.initRGB(34, 101, 178) };
                    } else if (lum == 3) {
                        c = Color{ .Bit24 = ColorBit24.initRGB(46, 111, 185) };
                    } else if (lum == 4) {
                        c = Color{ .Bit24 = ColorBit24.initRGB(58, 120, 192) };
                    } else if (lum == 5) {
                        c = Color{ .Bit24 = ColorBit24.initRGB(72, 131, 199) };
                    } else if (lum == 6) {
                        c = Color{ .Bit24 = ColorBit24.initRGB(88, 147, 215) };
                    } else if (lum == 7) {
                        c = Color{ .Bit24 = ColorBit24.initRGB(99, 154, 218) };
                    } else if (lum == 8) {
                        c = Color{ .Bit24 = ColorBit24.initRGB(113, 167, 229) };
                    } else if (lum == 9) {
                        c = Color{ .Bit24 = ColorBit24.initRGB(124, 176, 235) };
                    } else if (lum == 10) {
                        c = Color{ .Bit24 = ColorBit24.initRGB(140, 187, 240) };
                    } else if (lum == 11) {
                        c = Color{ .Bit24 = ColorBit24.initRGB(160, 202, 249) };
                    }
                    term.setCell(
                        Position{ .row = @intCast(u16, yp), .col = @intCast(u16, xp) },
                        Cell{
                            .rune = 'X',
                            .style = Style{
                                .fg_color = c,
                                .bg_color = Color.Default,
                                .decorations = Decorations{
                                    .bold = false,
                                    .italic = false,
                                    .underline = false,
                                    .blinking = false,
                                },
                            },
                        },
                    );
                }
            }
        }
        try term.drawScreen();
    }
}
