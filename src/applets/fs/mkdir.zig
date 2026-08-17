const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdMkdir(io: Io, args: []const [:0]const u8) !void {
    var parents = false;
    var mode: ?u32 = null;
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        const a = args[i];
        if (mem.eql(u8, a, "-p") or mem.eql(u8, a, "--parents")) {
            parents = true;
        } else if (mem.eql(u8, a, "-m") and i + 1 < args.len) {
            i += 1;
            mode = std.fmt.parseInt(u32, args[i], 8) catch null;
        } else if (a.len > 2 and a[0] == '-' and a[1] == 'm') {
            mode = std.fmt.parseInt(u32, a[2..], 8) catch null;
        } else if (mem.eql(u8, a, "--")) {
            i += 1;
            break;
        }
    }
    if (i >= args.len) {
        try util.writeAll(io, .stderr(), "mkdir: missing operand\n");
        std.process.exit(1);
    }
    for (args[i..]) |path| {
        if (parents) {
            Io.Dir.cwd().createDirPath(io, path) catch |err| {
                var buf: [512]u8 = undefined;
                const msg = try std.fmt.bufPrint(&buf, "mkdir: {s}: {s}\n", .{ path, @errorName(err) });
                try util.writeAll(io, .stderr(), msg);
            };
        } else {
            const perms = if (mode) |m| Io.File.Permissions.fromMode(@intCast(m)) else Io.File.Permissions.default_dir;
            Io.Dir.cwd().createDir(io, path, perms) catch |err| {
                var buf: [512]u8 = undefined;
                const msg = try std.fmt.bufPrint(&buf, "mkdir: {s}: {s}\n", .{ path, @errorName(err) });
                try util.writeAll(io, .stderr(), msg);
                continue;
            };
        }
        if (mode) |m| {
            const perms2 = Io.File.Permissions.fromMode(@intCast(m));
            Io.Dir.cwd().setFilePermissions(io, path, perms2, .{}) catch {};
        }
    }
}
