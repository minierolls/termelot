// Copyright (c) 2020 Termelot Contributors.

// SPDX-License-Identifier: MIT
// This file is part of the Termelot project under the MIT license.

const std = @import("std");
const Builder = std.build.Builder;
const fs = std.fs;

pub fn targetRequiresLibC(target: std.zig.CrossTarget) bool {
    switch (target.getOsTag()) {
        .linux => switch (target.getCpuArch()) {
            .x86_64 => return false,
            .aarch64 => return false,
            .mipsel => return false,
            else => return true,
        },
        else => return true,
    }
}

pub fn build(b: *Builder) !void {
    const mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(.{});

    const output_path = fs.path.join(b.allocator, &[_][]const u8{
        b.build_root,
        "build",
    }) catch unreachable;

    // TODO: Wrap library with public C interface
    const lib = b.addStaticLibrary("termelot", "src/termelot.zig");
    lib.setBuildMode(mode);
    lib.setTarget(target);
    lib.setOutputDir(output_path);
    lib.linkLibC();
    lib.emit_h = true;

    b.default_step.dependOn(&lib.step);

    const lib_tests = b.addTest("src/termelot.zig");
    lib_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&lib_tests.step);
}
