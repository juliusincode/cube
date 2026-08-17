const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const posix = std.posix;
const util = @import("util");

pub fn cmdUptime(io: Io, args: []const [:0]const u8) !void {
    _ = args;
    const linux = std.os.linux;
    var info: linux.Sysinfo = undefined;
    if (linux.sysinfo(&info) != 0) {
        try util.writeAll(io, .stderr(), "uptime: sysinfo failed\n");
        std.process.exit(1);
    }
    const up: i64 = info.uptime;
    const days = @divTrunc(up, 86400);
    const hours = @divTrunc(@rem(up, 86400), 3600);
    const mins = @divTrunc(@rem(up, 3600), 60);

    var wbuf: [256]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const w = &writer.interface;
    try w.writeAll("up ");
    if (days > 0) try w.print("{d} days, ", .{@as(u64, @intCast(days))});
    try w.print("{d}:{d:0>2}", .{ @as(u64, @intCast(hours)), @as(u64, @intCast(mins)) });
    // load averages: values are scaled by 65536
    const scale: f64 = 65536.0;
    const l0: f64 = @as(f64, @floatFromInt(info.loads[0])) / scale;
    const l1: f64 = @as(f64, @floatFromInt(info.loads[1])) / scale;
    const l2: f64 = @as(f64, @floatFromInt(info.loads[2])) / scale;
    try w.print(", load average: {d:.2}, {d:.2}, {d:.2}\n", .{ l0, l1, l2 });
    try w.flush();
}
