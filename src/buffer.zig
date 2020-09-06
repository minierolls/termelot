// Copyright (c) 2020 Termelot Contributors.

// SPDX-License-Identifier: MIT
// This file belongs to the Termelot project under the MIT license.

const std = @import("std");

const termelot = @import("termelot.zig");
const Size = termelot.Size;
const Position = termelot.Position;
const Cell = termelot.Cell;
const Rune = termelot.Rune;
usingnamespace termelot.style;
const Backend = termelot.Backend;

const default_size = Size{ .rows = 200, .cols = 300 };

// TODO: Add mutex lock and engage in relevant functions

pub const Buffer = struct {
    backend: *Backend,
    allocator: *std.mem.Allocator,
    default_rune: Rune,
    default_style: Style,
    size: Size,
    rune_buffer: std.ArrayList(Rune),
    style_buffer: std.ArrayList(Style),
    old_rune_buffer: std.ArrayList(Rune),
    old_style_buffer: std.ArrayList(Style),

    const Self = @This();

    pub fn init(
        backend: *Backend,
        allocator: *std.mem.Allocator,
        initial_size: ?Size,
    ) !Buffer {
        var result = Buffer{
            .backend = backend,
            .allocator = allocator,
            .size = initial_size orelse default_size,
            .default_rune = ' ',
            .default_style = Style{
                .fg_color = Color.Default,
                .bg_color = Color.Default,
                .decorations = Decorations{
                    .bold = false,
                    .italic = false,
                    .underline = false,
                    .blinking = false,
                },
            },
            .rune_buffer = std.ArrayList(Rune).init(allocator),
            .style_buffer = std.ArrayList(Style).init(allocator),
            .old_rune_buffer = std.ArrayList(Rune).init(allocator),
            .old_style_buffer = std.ArrayList(Style).init(allocator),
        };
        errdefer result.rune_buffer.deinit();
        errdefer result.style_buffer.deinit();
        errdefer result.old_rune_buffer.deinit();
        errdefer result.old_style_buffer.deinit();

        const buffer_length = @as(u32, result.size.rows) *
            @as(u32, result.size.cols);
        try result.rune_buffer.ensureCapacity(buffer_length);
        try result.style_buffer.ensureCapacity(buffer_length);
        try result.rune_buffer.resize(buffer_length);
        try result.style_buffer.resize(buffer_length);

        std.mem.set(
            Rune,
            result.rune_buffer.items,
            result.default_rune,
        );
        std.mem.set(
            Style,
            result.style_buffer.items,
            result.default_style,
        );

        return result;
    }

    pub fn deinit(self: *Self) void {
        self.old_rune_buffer.deinit();
        self.old_style_buffer.deinit();
        self.rune_buffer.deinit();
        self.style_buffer.deinit();
    }

    /// Set the default cell to use in operations such as `clear` and `resize`.
    pub fn setDefaultCell(self: *Self, new_default_cell: Cell) void {
        self.default_rune = new_default_cell.rune;
        self.default_style = new_default_cell.style;
    }
    /// Set the default rune to use in operations such as `clear` and `resize`.
    pub fn setDefaultRune(self: *Self, new_default_rune: Rune) void {
        self.default_rune = new_default_rune;
    }
    /// Set the default style to use in operations such as `clear` and `resize`.
    pub fn setDefaultStyle(self: *Self, new_default_style: Style) void {
        self.default_style = new_default_style;
    }

    /// Resize buffers keeping cells within the new buffer size, and filling
    /// new cells with the default cell. This function is expensive; minimize
    /// its use. If the function fails, then the buffer will not be modified.
    pub fn resize(self: *Self, new_size: Size, fill_cell: ?Cell) !void {
        if (self.size.equal(new_size)) return;

        const b_rows = self.buffer_size.rows;
        const b_cols = self.buffer_size.cols;
        const b_length = @as(u32, b_rows) * @as(u32, b_cols);

        const n_rows = new_size.rows;
        const n_cols = new_size.cols;
        const n_length = @as(u32, n_rows) * @as(u32, n_cols);

        const fill = fill_cell orelse Cell{
            .rune = self.default_rune,
            .style = self.default_style,
        };

        // Sanity checks
        {
            std.debug.assert(self.rune_buffer.items.len == b_length);
            std.debug.assert(self.style_buffer.items.len == b_length);
        }

        // Only make changes to buffer *after* all potential fail points
        if (n_length > b_length) {
            try self.rune_buffer.ensureCapacity(n_length);
            try self.style_buffer.ensureCapacity(n_length);
            self.rune_buffer.expandToCapacity();
            self.style_buffer.expandToCapacity();
        }

        // Copy buffer content to new positions and fill empty with defaults
        if (n_cols < b_cols) {
            var row_index: u16 = 1;
            while (row_index < b_rows) : (row_index += 1) {
                const source_start = row_index * b_cols;
                const source_end = row_index * b_cols + n_cols;
                const dest_start = row_index * n_cols;
                const dest_end = (row_index + 1) * n_cols;

                std.mem.copy(
                    Rune,
                    self.rune_buffer.items[dest_start..dest_end],
                    self.rune_buffer.items[source_start..source_end],
                );
                std.mem.copy(
                    Style,
                    self.style_buffer.items[dest_start..dest_end],
                    self.style_buffer.items[source_start..source_end],
                );
            }
        } else if (n_cols > b_cols) {
            var row: u16 = b_rows;
            while (row > 0) : (row -= 1) {
                const row_index = row - 1;

                const source_start = row_index * b_cols;
                const source_end = (row_index + 1) * b_cols;
                const dest_start = row_index * n_cols;
                const dest_end = row_index * n_cols + b_cols;
                const empty_start = dest_end;
                const empty_end = (row_index + 1) * n_cols;

                std.mem.copyBackwards(
                    Rune,
                    self.rune_buffer.items[dest_start..dest_end],
                    self.rune_buffer.items[source_start..source_end],
                );
                std.mem.copyBackwards(
                    Style,
                    self.style_buffer.items[dest_start..dest_end],
                    self.style_buffer.items[source_start..source_end],
                );

                std.mem.set(
                    Rune,
                    self.rune_buffer.items[empty_start..empty_end],
                    fill_rune,
                );
                std.mem.set(
                    Style,
                    self.style_buffer.items[empty_start..empty_end],
                    fill_style,
                );
            }
        }

        if (n_rows > b_rows) {
            const empty_start = b_rows * n_cols;
            const empty_end = n_rows * n_cols;

            std.mem.set(
                Rune,
                self.rune_buffer.items[empty_start..empty_end],
                fill_rune,
            );
            std.mem.set(
                Style,
                self.style_buffer.items[empty_start..empty_end],
                fill_style,
            );
        }

        self.size = new_size;

        self.rune_buffer.items.len = n_length;
        self.style_buffer.items.len = n_length;

        // Necessitate a full repaint of screen
        self.old_rune_buffer.items.len = 0;
        self.old_style_buffer.items.len = 0;
    }

    /// Draw diffs to screen. Cursor position is not guaranteed after draw.
    pub fn draw(self: *Self, screen_size: Size) !void {
        if (self.old_rune_buffer.items.len == 0 and
            self.old_style_buffer.items.len == 0)
        {
            return self.drawForce(screen_size);
        }

        const b_len = @as(u32, self.size.rows) * @as(u32, self.size.cols);
        // Sanity checks
        {
            std.debug.assert(self.rune_buffer.items.len == b_len);
            std.debug.assert(self.style_buffer.items.len == b_len);
            std.debug.assert(self.old_rune_buffer.items.len == b_len);
            std.debug.assert(self.old_style_buffer.items.len == b_len);
        }

        {
            var row_index: u16 = 0;
            while (row_index < screen_size.rows) : (row_index += 1) {
                var diff_origin: ?u32 = null;

                // TODO: Think again about how to handle newlines; it wouldn't
                //       be nice to let users set a cell as a newline, and
                //       then all of a sudden the cells set afterwards are
                //       implicitly shifted down a row

                // Do not batch adjacent diffs across lines, to avoid newline
                var col_index: u16 = 0;
                while (col_index < screen_size.cols) : (col_index += 1) {
                    const b_index = @as(u32, row_index) *
                        @as(u32, self.size.cols) +
                        @as(u32, col_index);

                    if (std.meta.eql(
                        self.rune_buffer.items[b_index],
                        self.old_rune_buffer.items[b_index],
                    ) and
                        std.meta.eql(
                        self.style_buffer.items[b_index],
                        self.old_style_buffer.items[b_index],
                    )) {
                        if (diff_origin) |i| {
                            try self.backend.write(
                                Position{ .row = row_index, .col = col_index },
                                self.rune_buffer.items[i..b_index],
                                self.style_buffer.items[i..b_index],
                            );
                        }
                        diff_origin = null;
                    } else if (diff_origin == null) {
                        diff_origin = b_index;
                    }
                }

                if (diff_origin) |i| {
                    try self.backend.write(
                        Position{ .row = row_index, .col = col_index },
                        self.rune_buffer.items[i..b_len],
                        self.style_buffer.items[i..b_len],
                    );
                }
            }
        }

        // Copy current buffer to old buffer
        std.mem.copy(
            Rune,
            self.old_rune_buffer.items,
            self.rune_buffer.items,
        );
        std.mem.copy(
            Style,
            self.old_style_buffer.items,
            self.style_buffer.items,
        );
    }
    /// Draw buffer to screen. Cursor position is not guaranteed after draw.
    pub fn drawForce(self: *Self, screen_size: Size) !void {
        const b_len = @as(u32, self.size.rows) * @as(u32, self.size.cols);

        // Sanity checks
        {
            std.debug.assert(self.rune_buffer.items.len == b_len);
            std.debug.assert(self.style_buffer.items.len == b_len);
        }

        try self.old_rune_buffer.ensureCapacity(b_len);
        try self.old_style_buffer.ensureCapacity(b_len);

        {
            var row_index: u16 = 0;
            while (row_index < screen_size.rows) : (row_index += 1) {
                const row_start: u32 = @as(u32, row_index) *
                    @as(u32, self.size.cols);
                const row_end: u32 = row_start + @as(u32, screen_size.cols);
                try self.backend.write(
                    Position{ .row = row_index, .col = 0 },
                    self.rune_buffer.items[row_start..row_end],
                    self.style_buffer.items[row_start..row_end],
                );
            }
        }

        // Copy current buffer to old buffer
        self.old_rune_buffer.items.len = b_len;
        self.old_style_buffer.items.len = b_len;

        std.mem.copy(
            Rune,
            self.old_rune_buffer.items,
            self.rune_buffer.items,
        );
        std.mem.copy(
            Style,
            self.old_style_buffer.items,
            self.style_buffer.items,
        );
    }

    /// Clear and fill the buffer with defaults.
    pub fn clear(self: *Self) void {
        const b_len = @as(u32, self.size.rows) * @as(u32, self.size.cols);

        // Sanity checks
        {
            std.debug.assert(self.rune_buffer.items.len == b_len);
            std.debug.assert(self.style_buffer.items.len == b_len);
        }

        std.mem.set(Rune, self.rune_buffer.items, self.default_rune);
        std.mem.set(Style, self.style_buffer.items, self.default_style);

        self.old_rune_buffer.items.len = 0;
        self.old_style_buffer.items.len = 0;
    }

    // TODO: Should this also return through a result argument?
    /// Get a cell within the buffer. `null` if position is outside buffer.
    pub fn getCell(self: Self, position: Position) ?Cell {
        if (position.row >= self.size.rows or position.col >= self.size.cols) {
            return null;
        }
        const p_index = @as(u32, position.row) *
            @as(u32, self.size.cols) +
            @as(u32, position.col);
        return Cell{
            .rune = self.rune_buffer.items[p_index],
            .style = self.style_buffer.items[p_index],
        };
    }
    /// Get a slice of cells within the buffer. This slice cannot span across
    /// rows. Results will be placed in provided "result", and the number of
    /// cells filled will be returned (only less than the specified length if
    /// the slice extends past the edges of the buffer). If position is outside
    /// the buffer, `null` is returned instead.
    pub fn getCells(
        self: Self,
        position: Position,
        length: u16,
        result: *[length]Cell,
    ) ?u16 {
        if (position.row >= self.size.rows or position.col >= self.size.cols) {
            return null;
        }
        const row_index = @as(u32, position.row) * @as(u32, self.size.cols);
        var offset: u16 = 0;
        while (position.col + offset < self.size.cols) : (offset += 1) {
            const index = row_index + @as(u32, position.col + offset);
            result[offset] = Cell{
                .rune = self.rune_buffer.items[index],
                .style = self.style_buffer.items[index],
            };
        }
        return offset;
    }
    /// Set a cell within the buffer. Ignored if position is outside buffer.
    pub fn setCell(self: *Self, position: Position, new_cell: Cell) void {
        if (position.row >= self.size.rows or position.col >= self.size.cols) {
            return;
        }
        const index = @as(u32, position.row) *
            @as(u32, self.size.cols) +
            @as(u32, position.col);
        self.rune_buffer.items[index] = new_cell.rune;
        self.style_buffer.items[index] = new_cell.style;
    }
    /// Set a slice of cells within the buffer. Cells that would extend beyond
    /// the buffer are ignored.
    pub fn setCells(self: *Self, position: Position, new_cells: []Cell) void {
        if (position.row >= self.size.rows or position.col >= self.size.cols) {
            return;
        }
        const row_index = @as(u32, position.row) * @as(u32, self.size.cols);
        for (new_cells) |new_cell, offset| {
            if (position.col + offset >= self.size.cols) break;
            const index = row_index + @as(u32, position.col + offset);
            self.rune_buffer.items[index] = new_cell.rune;
            self.style_buffer.items[index] = new_cell.style;
        }
    }
    /// Fill a slice of cells within the buffer. Cells that would extend beyond
    /// the buffer are ignored.
    pub fn fillCells(
        self: *Self,
        position: Position,
        length: u16,
        new_cell: Cell,
    ) void {
        if (position.row >= self.size.rows or position.col >= self.size.cols) {
            return;
        }
        const row_index = @as(u32, position.row) * @as(u32, self.size.cols);
        var offset: u16 = 0;
        while (position.col + offset < self.size.cols) : (offset += 1) {
            const index = row_index + @as(u32, position.col + offset);
            self.rune_buffer.items[index] = new_cell.rune;
            self.rune_buffer.items[index] = new_cell.style;
        }
    }
};
