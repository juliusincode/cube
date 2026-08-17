const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const posix = std.posix;
const util = @import("util");

pub fn cmdSleep(io: Io, args: []const [:0]const u8) !void {
    if (args.len < 2) {
        try util.writeAll(io, .stderr(), "sleep: missing operand\n");
        std.process.exit(1);
    }
    const secs = std.fmt.parseFloat(f64, args[1]) catch {
        try util.writeAll(io, .stderr(), "sleep: invalid time\n");
        std.process.exit(1);
    };
    const ns: i96 = @intFromFloat(secs * 1_000_000_000.0);
    try Io.sleep(io, .{ .nanoseconds = ns }, .real);
}
