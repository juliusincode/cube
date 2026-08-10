const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Shared library modules
    const util_mod = b.createModule(.{
        .root_source_file = b.path("src/util.zig"),
        .target = target,
        .optimize = optimize,
    });

    const text_mod = b.createModule(.{
        .root_source_file = b.path("src/applets/text.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "util", .module = util_mod },
        },
    });

    const fs_mod = b.createModule(.{
        .root_source_file = b.path("src/applets/fs.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "util", .module = util_mod },
        },
    });

    const sys_mod = b.createModule(.{
        .root_source_file = b.path("src/applets/sys.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "util", .module = util_mod },
        },
    });

    const version_mod = b.createModule(.{
        .root_source_file = b.path("src/version.zig"),
        .target = target,
        .optimize = optimize,
    });

    const applets_list_mod = b.createModule(.{
        .root_source_file = b.path("src/applets_list.zig"),
        .target = target,
        .optimize = optimize,
    });

    const root_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "util", .module = util_mod },
            .{ .name = "text", .module = text_mod },
            .{ .name = "fs", .module = fs_mod },
            .{ .name = "sys", .module = sys_mod },
            .{ .name = "version", .module = version_mod },
            .{ .name = "applets_list", .module = applets_list_mod },
        },
    });

    const exe = b.addExecutable(.{
        .name = "cube",
        .root_module = root_mod,
    });
    b.installArtifact(exe);

    const run_step = b.step("run", "Run cube");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // Unit tests for each module
    const test_step = b.step("test", "Run unit tests");

    const modules = [_]struct { name: []const u8, mod: *std.Build.Module }{
        .{ .name = "main", .mod = root_mod },
        .{ .name = "util", .mod = util_mod },
        .{ .name = "text", .mod = text_mod },
        .{ .name = "fs", .mod = fs_mod },
        .{ .name = "sys", .mod = sys_mod },
    };

    for (modules) |m| {
        // Re-create with Debug for clearer test failures
        _ = m.name;
        const unit = b.addTest(.{
            .root_module = m.mod,
        });
        const run_unit = b.addRunArtifact(unit);
        test_step.dependOn(&run_unit.step);
    }
}
