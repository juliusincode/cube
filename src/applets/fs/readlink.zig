const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdReadlink(io: Io, args: []const [:0]const u8) !void {
    var i: usize = 1;
    var no_newline = false;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        for (args[i][1..]) |c| {
            if (c == 'n') no_newline = true;
        }
    }
    if (i >= args.len) {
        try util.writeAll(io, .stderr(), "readlink: missing operand\n");
        std.process.exit(1);
    }
    const path = args[i];
    var buf: [Io.Dir.max_path_bytes]u8 = undefined;
    const n = Io.Dir.cwd().readLink(io, path, &buf) catch |err| {
        var ebuf: [256]u8 = undefined;
        const msg = try std.fmt.bufPrint(&ebuf, "readlink: {s}: {s}\n", .{ path, @errorName(err) });
        try util.writeAll(io, .stderr(), msg);
        std.process.exit(1);
    };
    try util.writeAll(io, .stdout(), buf[0..n]);
    if (!no_newline) try util.writeAll(io, .stdout(), "\n");
}
