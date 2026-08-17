const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const posix = std.posix;
const util = @import("util");

pub fn cmdWhoami(io: Io) !void {
    const uid = std.os.linux.getuid();
    var buf: [32]u8 = undefined;
    const msg = try std.fmt.bufPrint(&buf, "{d}\n", .{uid});
    try util.writeAll(io, .stdout(), msg);
}
