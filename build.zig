// Copyright (c) 2020 Termelot Contributors.

// SPDX-License-Identifier: MIT
// This file is part of the Termelot project under the MIT license.

const std = @import("std");
const Builder = std.build.Builder;
const fs = std.fs;

pub fn build(b: *Builder) !void {
    b.setPreferredReleaseMode(.ReleaseFast);
    const mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(.{});

    const output_path = fs.path.join(b.allocator, &[_][]const u8{
        b.build_root,
        "build",
    }) catch unreachable;

    // TODO: Wrap library with public C interface
    // const lib = b.addStaticLibrary("termelot", "src/termelot.zig");
    // lib.setBuildMode(mode);
    // lib.setTarget(target);
    // lib.setOutputDir(output_path);
    // lib.linkLibC();
    // lib.emit_h = true;

    // b.default_step.dependOn(&lib.step);

    const lib_tests = b.addTest("src/termelot.zig");
    lib_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&lib_tests.step);

    const examples_output_path = fs.path.join(b.allocator, &[_][]const u8{
        b.build_root,
        "build",
        "examples",
    }) catch unreachable;

    var ziro = b.addExecutable("ziro", "examples/ziro.zig");
    ziro.setBuildMode(mode);
    ziro.setTarget(target);
    ziro.setOutputDir(examples_output_path);
    ziro.addPackagePath("termelot", "src/termelot.zig");
    ziro.linkLibC();

    const ziro_run_cmd = ziro.run();

    const ziro_run_step = b.step("ziro", "Run the `ziro` example");
    ziro_run_step.dependOn(&ziro_run_cmd.step);

    var donut = b.addExecutable("donut", "examples/donut.zig");
    donut.setBuildMode(mode);
    donut.setTarget(target);
    donut.setOutputDir(examples_output_path);
    donut.addPackagePath("termelot", "src/termelot.zig");
    donut.linkLibC();

    const donut_run_cmd = donut.run();

    const donut_run_step = b.step("donut", "Run the `donut` example");
    donut_run_step.dependOn(&donut_run_cmd.step);

    var init = b.addExecutable("init", "examples/init.zig");
    init.setBuildMode(mode);
    init.setTarget(target);
    init.setOutputDir(examples_output_path);
    init.addPackagePath("termelot", "src/termelot.zig");
    init.linkLibC();

    const init_run_cmd = init.run();

    const init_run_step = b.step("init", "Run the `init` example");
    init_run_step.dependOn(&init_run_cmd.step);
}
