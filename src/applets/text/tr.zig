const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdTr(io: Io, args: []const [:0]const u8) !void {
    // tr [-d] SET1 [SET2]  — character translation / delete
    var delete = false;
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        for (args[i][1..]) |c| {
            if (c == 'd') delete = true;
        }
    }
    if (i >= args.len) {
        try util.writeAll(io, .stderr(), "tr: missing operand\n");
        std.process.exit(1);
    }
    var set1_buf: [256]u8 = undefined;
    const set1 = expandTrSet(args[i], &set1_buf);
    i += 1;
    var set2_buf: [256]u8 = undefined;
    const set2: ?[]const u8 = if (!delete and i < args.len) expandTrSet(args[i], &set2_buf) else null;

    // Build map for translation
    var map: [256]?u8 = [_]?u8{null} ** 256;
    var delete_set: [256]bool = [_]bool{false} ** 256;
    if (delete) {
        for (set1) |c| delete_set[c] = true;
    } else if (set2) |s2| {
        if (s2.len == 0) {
            try util.writeAll(io, .stderr(), "tr: missing operand\n");
            std.process.exit(1);
        }
        var k: usize = 0;
        while (k < set1.len) : (k += 1) {
            const from = set1[k];
            const to = if (k < s2.len) s2[k] else s2[s2.len - 1];
            map[from] = to;
        }
    }

    var rbuf: [8192]u8 = undefined;
    var reader: Io.File.Reader = .init(.stdin(), io, &rbuf);
    var wbuf: [8192]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const w = &writer.interface;
    var outbuf: [8192]u8 = undefined;
    while (true) {
        const n = reader.interface.readSliceShort(&outbuf) catch |err| return err;
        if (n == 0) break;
        for (outbuf[0..n]) |c| {
            if (delete) {
                if (!delete_set[c]) try w.writeAll(&.{c});
            } else if (map[c]) |to| {
                try w.writeAll(&.{to});
            } else {
                try w.writeAll(&.{c});
            }
        }
    }
    try w.flush();
}

fn expandTrSet(s: []const u8, buf: *[256]u8) []const u8 {
    // Expand a-z style ranges into provided buffer
    var len: usize = 0;
    var i: usize = 0;
    while (i < s.len and len < 256) {
        if (i + 2 < s.len and s[i + 1] == '-' and s[i] <= s[i + 2]) {
            var c: u8 = s[i];
            while (c <= s[i + 2] and len < 256) : (c += 1) {
                buf[len] = c;
                len += 1;
                if (c == 255) break;
            }
            i += 3;
        } else {
            buf[len] = s[i];
            len += 1;
            i += 1;
        }
    }
    return buf[0..len];
}
