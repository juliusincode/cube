const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const posix = std.posix;
const util = @import("util");

pub fn cmdArch(io: Io, args: []const [:0]const u8) !void {
    _ = args;
    const arch = @tagName(builtin.cpu.arch);
    try util.writeAll(io, .stdout(), arch);
    try util.writeAll(io, .stdout(), "\n");
}
