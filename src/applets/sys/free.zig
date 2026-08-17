const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const posix = std.posix;
const util = @import("util");

pub fn cmdFree(io: Io, args: []const [:0]const u8) !void {
    var human = false;
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        for (args[i][1..]) |c| {
            if (c == 'h') human = true;
        }
    }

    const linux = std.os.linux;
    var info: linux.Sysinfo = undefined;
    if (linux.sysinfo(&info) != 0) {
        try util.writeAll(io, .stderr(), "free: sysinfo failed\n");
        std.process.exit(1);
    }
    const unit: u64 = if (info.mem_unit == 0) 1 else info.mem_unit;
    const total = info.totalram * unit;
    const free_r = info.freeram * unit;
    const shared = info.sharedram * unit;
    const buffers = info.bufferram * unit;
    const used = if (total > free_r) total - free_r else 0;
    const swap_total = info.totalswap * unit;
    const swap_free = info.freeswap * unit;
    const swap_used = if (swap_total > swap_free) swap_total - swap_free else 0;

    var wbuf: [512]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const w = &writer.interface;

    if (human) {
        var b: [5][16]u8 = undefined;
        try w.writeAll("              total        used        free      shared     buffers\n");
        try w.print("Mem:    {s:>12} {s:>12} {s:>12} {s:>12} {s:>12}\n", .{
            formatBytes(&b[0], total),
            formatBytes(&b[1], used),
            formatBytes(&b[2], free_r),
            formatBytes(&b[3], shared),
            formatBytes(&b[4], buffers),
        });
        try w.print("Swap:   {s:>12} {s:>12} {s:>12}\n", .{
            formatBytes(&b[0], swap_total),
            formatBytes(&b[1], swap_used),
            formatBytes(&b[2], swap_free),
        });
    } else {
        try w.writeAll("              total        used        free      shared     buffers\n");
        try w.print("Mem:    {d:>12} {d:>12} {d:>12} {d:>12} {d:>12}\n", .{
            total / 1024, used / 1024, free_r / 1024, shared / 1024, buffers / 1024,
        });
        try w.print("Swap:   {d:>12} {d:>12} {d:>12}\n", .{
            swap_total / 1024, swap_used / 1024, swap_free / 1024,
        });
    }
    try w.flush();
}

fn formatBytes(buf: []u8, size: u64) []const u8 {
    const units = [_][]const u8{ "B", "K", "M", "G", "T" };
    var s: f64 = @floatFromInt(size);
    var u: usize = 0;
    while (s >= 1024.0 and u + 1 < units.len) : (u += 1) {
        s /= 1024.0;
    }
    if (u == 0) return std.fmt.bufPrint(buf, "{d}{s}", .{ size, units[u] }) catch "?";
    if (s >= 10.0) return std.fmt.bufPrint(buf, "{d:.0}{s}", .{ s, units[u] }) catch "?";
    return std.fmt.bufPrint(buf, "{d:.1}{s}", .{ s, units[u] }) catch "?";
}
