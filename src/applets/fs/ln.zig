const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdLn(io: Io, args: []const [:0]const u8) !void {
    var symbolic = false;
    var force = false;
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        const a = args[i];
        if (mem.eql(u8, a, "--")) {
            i += 1;
            break;
        }
        for (a[1..]) |c| {
            switch (c) {
                's' => symbolic = true,
                'f' => force = true,
                else => {},
            }
        }
    }
    if (i + 1 >= args.len) {
        try util.writeAll(io, .stderr(), "ln: missing file operand\n");
        std.process.exit(1);
    }
    const target = args[i];
    const linkpath = args[i + 1];
    const cwd = Io.Dir.cwd();

    if (force) {
        cwd.deleteFile(io, linkpath) catch {};
    }

    if (symbolic) {
        cwd.symLink(io, target, linkpath, .{}) catch |err| {
            var buf: [512]u8 = undefined;
            const msg = try std.fmt.bufPrint(&buf, "ln: {s}\n", .{@errorName(err)});
            try util.writeAll(io, .stderr(), msg);
            std.process.exit(1);
        };
    } else {
        cwd.hardLink(target, cwd, linkpath, io, .{}) catch |err| {
            var buf: [512]u8 = undefined;
            const msg = try std.fmt.bufPrint(&buf, "ln: {s}\n", .{@errorName(err)});
            try util.writeAll(io, .stderr(), msg);
            std.process.exit(1);
        };
    }
}
