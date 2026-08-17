const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const posix = std.posix;
const util = @import("util");

pub fn cmdClear(io: Io) !void {
    try util.writeAll(io, .stdout(), "\x1b[2J\x1b[H");
}
