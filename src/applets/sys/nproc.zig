const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const posix = std.posix;
const util = @import("util");

pub fn cmdNproc(io: Io, args: []const [:0]const u8) !void {
    _ = args;
    const n = std.Thread.getCpuCount() catch 1;
    var buf: [32]u8 = undefined;
    const s = try std.fmt.bufPrint(&buf, "{d}\n", .{n});
    try util.writeAll(io, .stdout(), s);
}
