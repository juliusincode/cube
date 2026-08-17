const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const posix = std.posix;
const util = @import("util");

pub fn cmdDate(io: Io, args: []const [:0]const u8) !void {
    const ts = Io.Timestamp.now(io, .real);
    const secs: i64 = @intCast(@divTrunc(ts.nanoseconds, 1_000_000_000));

    // Optional +FORMAT
    var fmt_str: ?[]const u8 = null;
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (args[i].len > 0 and args[i][0] == '+') {
            fmt_str = args[i][1..];
            break;
        }
    }

    var wbuf: [512]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const w = &writer.interface;

    if (fmt_str) |fmt| {
        try formatDate(w, secs, fmt);
        try w.writeAll("\n");
    } else {
        // default: human-ish local breakdown + epoch
        try formatDate(w, secs, "%Y-%m-%d %H:%M:%S");
        try w.writeAll("\n");
    }
    try w.flush();
}

fn formatDate(w: anytype, epoch_secs: i64, fmt: []const u8) !void {
    // Civil date from days (Howard Hinnant algorithm)
    const secs_per_day: i64 = 86400;
    var days = @divTrunc(epoch_secs, secs_per_day);
    var sod = @rem(epoch_secs, secs_per_day);
    if (sod < 0) {
        sod += secs_per_day;
        days -= 1;
    }
    const hour: u32 = @intCast(@divTrunc(sod, 3600));
    const minute: u32 = @intCast(@divTrunc(@rem(sod, 3600), 60));
    const second: u32 = @intCast(@rem(sod, 60));

    const z = days + 719468;
    const era = if (z >= 0) @divTrunc(z, 146097) else @divTrunc(z - 146096, 146097);
    const doe: u32 = @intCast(z - era * 146097);
    const yoe: u32 = @divTrunc(doe - @divTrunc(doe, 1460) + @divTrunc(doe, 36524) - @divTrunc(doe, 146096), 365);
    var y: i32 = @intCast(yoe + era * 400);
    const doy: u32 = doe - (365 * yoe + @divTrunc(yoe, 4) - @divTrunc(yoe, 100));
    const mp: u32 = @divTrunc(5 * doy + 2, 153);
    const d: u32 = doy - @divTrunc(153 * mp + 2, 5) + 1;
    const m: u32 = if (mp < 10) mp + 3 else mp - 9;
    if (m <= 2) y += 1;

    const months = [_][]const u8{ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };
    const days_w = [_][]const u8{ "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" };
    // 1970-01-01 was Thursday → (days + 4) mod 7
    const wday: u32 = @intCast(@mod(days + 4, 7));

    var fi: usize = 0;
    while (fi < fmt.len) {
        if (fmt[fi] == '%' and fi + 1 < fmt.len) {
            fi += 1;
            const c = fmt[fi];
            fi += 1;
            switch (c) {
                'Y' => try w.print("{d:0>4}", .{@as(u32, @intCast(y))}),
                'm' => try w.print("{d:0>2}", .{m}),
                'd' => try w.print("{d:0>2}", .{d}),
                'H' => try w.print("{d:0>2}", .{hour}),
                'M' => try w.print("{d:0>2}", .{minute}),
                'S' => try w.print("{d:0>2}", .{second}),
                's' => try w.print("{d}", .{epoch_secs}),
                'b' => try w.writeAll(months[m - 1]),
                'a' => try w.writeAll(days_w[wday]),
                '%' => try w.writeAll("%"),
                else => {
                    try w.writeAll("%");
                    try w.writeAll(&.{c});
                },
            }
        } else {
            try w.writeAll(fmt[fi .. fi + 1]);
            fi += 1;
        }
    }
}
