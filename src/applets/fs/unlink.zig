const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdUnlink(io: Io, args: []const [:0]const u8) !void {
    // unlink FILE  — remove a single file (not directory)
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {}
    if (i >= args.len) {
        try util.writeAll(io, .stderr(), "unlink: missing operand\n");
        std.process.exit(1);
    }
    // POSIX unlink takes exactly one file; allow multiple like busybox sometimes does
    var failed = false;
    while (i < args.len) : (i += 1) {
        Io.Dir.cwd().deleteFile(io, args[i]) catch |err| {
            var buf: [256]u8 = undefined;
            const msg = try std.fmt.bufPrint(&buf, "unlink: {s}: {s}\n", .{ args[i], @errorName(err) });
            try util.writeAll(io, .stderr(), msg);
            failed = true;
        };
    }
    if (failed) std.process.exit(1);
}
