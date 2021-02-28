// Copyright (c) 2020 Termelot Contributors.

// SPDX-License-Identifier: MIT
// This file is part of the Termelot project under the MIT license.

const std = @import("std");
const builtin = std.builtin;

pub const backend = switch (builtin.os.tag) {
    .linux, .macos, .dragonfly, .freebsd, .openbsd => @import("backend/termios.zig"),
    .windows => @import("backend/windows.zig"),
    else => @import("backend/unimplemented.zig"),
};
