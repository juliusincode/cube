const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdOd(io: Io, args: []const [:0]const u8) !void {
    // od [-A x|o|n] [-t x1|o1|c] [-N N] [FILE]...
    // Minimal: default address in hex, bytes as hex pairs (like od -An -tx1 simplified with addresses)
    var addr_base: u8 = 'x'; // x, o, or n (none)
    var max_bytes: ?usize = null;
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        const a = args[i];
        if (mem.eql(u8, a, "-A") and i + 1 < args.len) {
            i += 1;
            if (args[i].len > 0) addr_base = args[i][0];
        } else if (mem.eql(u8, a, "-N") and i + 1 < args.len) {
            i += 1;
            max_bytes = std.fmt.parseInt(usize, args[i], 10) catch null;
        } else if (mem.eql(u8, a, "-t") and i + 1 < args.len) {
            i += 1; // accept but we always print hex bytes
        }
    }

    const path: []const u8 = if (i < args.len) args[i] else "-";
    const file = if (mem.eql(u8, path, "-"))
        Io.File.stdin()
    else
        Io.Dir.cwd().openFile(io, path, .{}) catch |err| {
            var buf: [256]u8 = undefined;
            const msg = try std.fmt.bufPrint(&buf, "od: {s}: {s}\n", .{ path, @errorName(err) });
            try util.writeAll(io, .stderr(), msg);
            std.process.exit(1);
        };
    defer if (!mem.eql(u8, path, "-")) file.close(io);

    var rbuf: [4096]u8 = undefined;
    var reader: Io.File.Reader = .init(file, io, &rbuf);
    var wbuf: [4096]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const w = &writer.interface;

    var offset: u64 = 0;
    var total: usize = 0;
    var line_buf: [16]u8 = undefined;
    var line_len: usize = 0;

    while (true) {
        if (max_bytes) |mb| {
            if (total >= mb) break;
        }
        var tmp: [1]u8 = undefined;
        const n = reader.interface.readSliceShort(&tmp) catch break;
        if (n == 0) break;
        line_buf[line_len] = tmp[0];
        line_len += 1;
        total += 1;
        if (line_len == 16) {
            try writeOdLine(w, offset, line_buf[0..16], addr_base);
            offset += 16;
            line_len = 0;
        }
        if (max_bytes) |mb| {
            if (total >= mb) break;
        }
    }
    if (line_len > 0) {
        try writeOdLine(w, offset, line_buf[0..line_len], addr_base);
        offset += line_len;
    }
    // final address
    if (addr_base != 'n') {
        try writeOdAddr(w, offset, addr_base);
        try w.writeAll("\n");
    }
    try w.flush();
}

fn writeOdAddr(w: anytype, offset: u64, base: u8) !void {
    switch (base) {
        'o' => try w.print("{o:0>7}", .{offset}),
        'n' => {},
        else => try w.print("{x:0>7}", .{offset}),
    }
}

fn writeOdLine(w: anytype, offset: u64, bytes: []const u8, base: u8) !void {
    if (base != 'n') {
        try writeOdAddr(w, offset, base);
        try w.writeAll(" ");
    }
    for (bytes, 0..) |b, idx| {
        if (idx > 0) try w.writeAll(" ");
        try w.print("{x:0>2}", .{b});
    }
    try w.writeAll("\n");
}
