const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdRm(io: Io, arena: mem.Allocator, args: []const [:0]const u8) !void {
    _ = arena;
    var recursive = false;
    var force = false;
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        const opt = args[i];
        if (mem.eql(u8, opt, "--")) {
            i += 1;
            break;
        }
        if (mem.eql(u8, opt, "-r") or mem.eql(u8, opt, "-R") or mem.eql(u8, opt, "--recursive")) {
            recursive = true;
        } else if (mem.eql(u8, opt, "-f") or mem.eql(u8, opt, "--force")) {
            force = true;
        } else if (mem.eql(u8, opt, "-rf") or mem.eql(u8, opt, "-fr") or mem.eql(u8, opt, "-Rf") or mem.eql(u8, opt, "-fR")) {
            recursive = true;
            force = true;
        } else {
            // single-letter cluster e.g. -rf already handled; ignore others
        }
    }
    if (i >= args.len) {
        if (!force) {
            try util.writeAll(io, .stderr(), "rm: missing operand\n");
            std.process.exit(1);
        }
        return;
    }
    for (args[i..]) |path| {
        if (recursive) {
            Io.Dir.cwd().deleteTree(io, path) catch |err| {
                if (!force) {
                    var buf: [512]u8 = undefined;
                    const msg = try std.fmt.bufPrint(&buf, "rm: {s}: {s}\n", .{ path, @errorName(err) });
                    try util.writeAll(io, .stderr(), msg);
                }
            };
        } else {
            Io.Dir.cwd().deleteFile(io, path) catch |err| {
                if (!force) {
                    var buf: [512]u8 = undefined;
                    const msg = try std.fmt.bufPrint(&buf, "rm: {s}: {s}\n", .{ path, @errorName(err) });
                    try util.writeAll(io, .stderr(), msg);
                }
            };
        }
    }
}
