// Copyright (c) 2020 Termelot Contributors.

// SPDX-License-Identifier: MIT
// This file is part of the Termelot project under the MIT license.

const std = @import("std");
const Builder = std.build.Builder;
const LibExeObjStep = std.build.LibExeObjStep;
const Pkg = std.build.Pkg;
const fs = std.fs;

const BackendName = @import("src/backend.zig").BackendName;

const backends = @typeInfo(BackendName).Enum.fields;

// pub fn targetRequiresLibC(target: std.zig.CrossTarget) bool {
//     switch (target.getOsTag()) {
//         .linux => switch (target.getCpuArch()) {
//             .x86_64 => return false,
//             .aarch64 => return false,
//             .mipsel => return false,
//             else => return true,
//         },
//         else => return true,
//     }
// }

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
    lib.emit_h = true;

    const backend = try getBackend(b);
    const backend_path = backendNameToPath(backend);
    std.log.info("Selected {} for backend at {}.", .{ @tagName(backend), backend_path });

    // NOTE: make Pkg of backend and use it EVERYWHERE
    const backend_pkg = backendAsPkg(backend);

    lib.addPackage(backend_pkg);
    try applyBuildOptions(lib, backend);

    b.default_step.dependOn(&lib.step);

    const lib_tests = b.addTest("src/termelot.zig");
    lib_tests.setBuildMode(mode);
    // lib_tests.linkLibrary(lib);
    lib_tests.addPackage(backend_pkg);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&lib_tests.step);

    // Examples

    const lib_pkg = Pkg{
        .name = "termelot",
        .path = "src/termelot.zig",
        .dependencies = &[1]Pkg{backend_pkg},
    };

    addExample(b, lib_pkg, "init", "examples/init.zig", target, mode);
    addExample(b, lib_pkg, "donut", "examples/donut.zig", target, mode);
    addExample(b, lib_pkg, "castle", "examples/castle.zig", target, mode);
    addExample(b, lib_pkg, "ziro", "examples/ziro.zig", target, mode);
}

pub fn backendAsPkg(backend: BackendName) Pkg {
    return std.build.Pkg{
        .name = "backend",
        .path = backendNameToPath(backend),
        .dependencies = null,
    };
}

pub fn backendNameToPath(backend: BackendName) []const u8 {
    return switch (backend) {
        .termios => "src/backend/termios.zig",
        .windows => "src/backend/windows.zig",
        .ncurses => "src/backend/ncurses.zig",
        .unimplemented => "src/backend/unimplemented.zig",
    };
}

/// Combines target info and build options to determine the name of the backend to be compiled
/// into the library.
pub fn getBackend(b: *Builder) !BackendName {
    if (b.option([]const u8, "backend", "Override included backend")) |val| {
        inline for (backends) |backend| {
            if (std.mem.eql(u8, backend.name, val)) {
                return @intToEnum(BackendName, backend.value);
            }
        }
        std.log.crit("'{}' is not a backend choice. Possible backends include:", .{val});
        inline for (backends) |backend| {
            std.log.crit("{}", .{backend.name});
            return error.NoBackend;
        }
    } else {
        // Automatic backend selector
        return switch (std.builtin.os.tag) {
            .linux, .macos, .dragonfly, .freebsd, .openbsd => .termios,
            .windows => .windows,
            else => .unimplemented,
        };
    }
}

/// For a given backend, apply all build options and functions required.
pub fn applyBuildOptions(lib: *LibExeObjStep, backend: BackendName) !void {
    switch (backend) {
        .termios => lib.linkLibC(),
        .windows => lib.linkLibC(),
        .ncurses => {
            lib.linkLibC();
            lib.linkSystemLibrary("ncurses"); // TODO: some systems name this library "curses" or "ncursesw"
        },
        else => {},
    }
}

/// Add an example to the list of build options.
fn addExample(b: *Builder, lib_pkg: Pkg, comptime name: []const u8, root_src: []const u8, target: std.zig.CrossTarget, mode: std.builtin.Mode) void {
    const examples_output_path = fs.path.join(b.allocator, &[_][]const u8{
        b.build_root,
        "build",
        "examples",
    }) catch unreachable;

    const exe = b.addExecutable(name, root_src);
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.setOutputDir(examples_output_path);

    // Resolve imports for "termelot" and "backend"
    exe.addPackage(lib_pkg);

    const run_cmd = exe.run();

    const run_step = b.step(name, "Run the '" ++ name ++ "' example");
    run_step.dependOn(&run_cmd.step);
}
