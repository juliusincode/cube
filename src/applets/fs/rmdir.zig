const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdRmdir(io: Io, args: []const [:0]const u8) !void {
    if (args.len < 2) {
        try util.writeAll(io, .stderr(), "rmdir: missing operand\n");
        std.process.exit(1);
    }
    for (args[1..]) |path| {
        Io.Dir.cwd().deleteDir(io, path) catch |err| {
            var buf: [512]u8 = undefined;
            const msg = try std.fmt.bufPrint(&buf, "rmdir: {s}: {s}\n", .{ path, @errorName(err) });
            try util.writeAll(io, .stderr(), msg);
        };
    }
}
