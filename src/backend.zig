// Copyright (c) 2020 Termelot Contributors.
// This file is part of the Termelot project under the MIT license.

const builtin = @import("builtin");

pub const backend = switch (builtin.os.tag) {
    else => @import("backend/unimplemented.zig"),
};
