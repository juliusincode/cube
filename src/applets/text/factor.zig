const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdFactor(io: Io, args: []const [:0]const u8) !void {
    // factor [NUMBER]...
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {}

    var wbuf: [1024]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const w = &writer.interface;

    if (i >= args.len) {
        // read numbers from stdin
        var rbuf: [4096]u8 = undefined;
        var reader: Io.File.Reader = .init(.stdin(), io, &rbuf);
        while (true) {
            const line = (reader.interface.takeDelimiter('\n') catch break) orelse break;
            var it = mem.tokenizeAny(u8, line, " \t");
            while (it.next()) |tok| {
                try factorOne(w, tok);
            }
        }
    } else {
        while (i < args.len) : (i += 1) {
            try factorOne(w, args[i]);
        }
    }
    try w.flush();
}

fn factorOne(w: anytype, tok: []const u8) !void {
    const n = std.fmt.parseInt(u64, tok, 10) catch {
        try w.print("{s}: not a number\n", .{tok});
        return;
    };
    try w.print("{d}:", .{n});
    var x = n;
    if (x <= 1) {
        try w.writeAll("\n");
        return;
    }
    // factor out 2s
    while (x % 2 == 0) {
        try w.writeAll(" 2");
        x /= 2;
    }
    var f: u64 = 3;
    while (f * f <= x) : (f += 2) {
        while (x % f == 0) {
            try w.print(" {d}", .{f});
            x /= f;
        }
    }
    if (x > 1) try w.print(" {d}", .{x});
    try w.writeAll("\n");
}
