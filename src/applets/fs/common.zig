const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn formatHumanSize(buf: []u8, size: u64) []const u8 {
    const units = [_][]const u8{ "B", "K", "M", "G", "T" };
    var s: f64 = @floatFromInt(size);
    var u: usize = 0;
    while (s >= 1024.0 and u + 1 < units.len) : (u += 1) {
        s /= 1024.0;
    }
    if (u == 0) {
        return std.fmt.bufPrint(buf, "{d}{s}", .{ size, units[u] }) catch "?";
    }
    if (s >= 10.0) {
        return std.fmt.bufPrint(buf, "{d:.0}{s}", .{ s, units[u] }) catch "?";
    }
    return std.fmt.bufPrint(buf, "{d:.1}{s}", .{ s, units[u] }) catch "?";
}

test "formatHumanSize" {
    var buf: [32]u8 = undefined;
    try std.testing.expectEqualStrings("0B", formatHumanSize(&buf, 0));
    try std.testing.expectEqualStrings("512B", formatHumanSize(&buf, 512));
    try std.testing.expectEqualStrings("1.0K", formatHumanSize(&buf, 1024));
    try std.testing.expectEqualStrings("1.5K", formatHumanSize(&buf, 1536));
    try std.testing.expectEqualStrings("1.0M", formatHumanSize(&buf, 1024 * 1024));
}
