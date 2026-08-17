const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");
const common = @import("common.zig");

pub fn cmdSha256sum(io: Io, args: []const [:0]const u8) !void {
    try common.hashSum(io, args, .sha256);
}
