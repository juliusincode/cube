const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const posix = std.posix;
const util = @import("util");

pub fn cmdHostname(io: Io, args: []const [:0]const u8) !void {
    _ = args;
    const uts = posix.uname();
    const name = mem.sliceTo(&uts.nodename, 0);
    try util.writeAll(io, .stdout(), name);
    try util.writeAll(io, .stdout(), "\n");
}
