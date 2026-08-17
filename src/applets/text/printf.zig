const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdPrintf(io: Io, args: []const [:0]const u8) !void {
    if (args.len < 2) {
        // printf with no format → exit 0 (POSIX)
        return;
    }
    const fmt = args[1];
    var arg_i: usize = 2;

    var buf: [8192]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &buf);
    const w = &writer.interface;

    var i: usize = 0;
    while (i < fmt.len) {
        if (fmt[i] == '%' and i + 1 < fmt.len) {
            const spec = fmt[i + 1];
            i += 2;
            switch (spec) {
                '%' => try w.writeAll("%"),
                's' => {
                    const s = if (arg_i < args.len) args[arg_i] else "";
                    if (arg_i < args.len) arg_i += 1;
                    try w.writeAll(s);
                },
                'd', 'i' => {
                    const s = if (arg_i < args.len) args[arg_i] else "0";
                    if (arg_i < args.len) arg_i += 1;
                    const n = std.fmt.parseInt(i64, s, 10) catch 0;
                    try w.print("{d}", .{n});
                },
                'u' => {
                    const s = if (arg_i < args.len) args[arg_i] else "0";
                    if (arg_i < args.len) arg_i += 1;
                    const n = std.fmt.parseInt(u64, s, 10) catch 0;
                    try w.print("{d}", .{n});
                },
                'x' => {
                    const s = if (arg_i < args.len) args[arg_i] else "0";
                    if (arg_i < args.len) arg_i += 1;
                    const n = std.fmt.parseInt(u64, s, 10) catch 0;
                    try w.print("{x}", .{n});
                },
                'X' => {
                    const s = if (arg_i < args.len) args[arg_i] else "0";
                    if (arg_i < args.len) arg_i += 1;
                    const n = std.fmt.parseInt(u64, s, 10) catch 0;
                    try w.print("{X}", .{n});
                },
                'c' => {
                    const s = if (arg_i < args.len) args[arg_i] else "";
                    if (arg_i < args.len) arg_i += 1;
                    if (s.len > 0) try w.writeAll(s[0..1]);
                },
                else => {
                    // unknown → print literally
                    try w.writeAll("%");
                    try w.writeAll(&.{spec});
                },
            }
        } else if (fmt[i] == '\\' and i + 1 < fmt.len) {
            const esc = fmt[i + 1];
            i += 2;
            switch (esc) {
                'n' => try w.writeAll("\n"),
                't' => try w.writeAll("\t"),
                'r' => try w.writeAll("\r"),
                '\\' => try w.writeAll("\\"),
                '0' => try w.writeAll(&.{0}),
                else => {
                    try w.writeAll(&.{'\\'});
                    try w.writeAll(&.{esc});
                },
            }
        } else {
            try w.writeAll(fmt[i .. i + 1]);
            i += 1;
        }
    }
    try w.flush();
}
