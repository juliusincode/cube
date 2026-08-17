const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdWc(io: Io, args: []const [:0]const u8) !void {
    var show_lines = false;
    var show_words = false;
    var show_bytes = false;
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        const a = args[i];
        if (mem.eql(u8, a, "--")) {
            i += 1;
            break;
        }
        for (a[1..]) |c| {
            switch (c) {
                'l' => show_lines = true,
                'w' => show_words = true,
                'c' => show_bytes = true,
                else => {},
            }
        }
    }
    // default: all three
    if (!show_lines and !show_words and !show_bytes) {
        show_lines = true;
        show_words = true;
        show_bytes = true;
    }

    const files: []const [:0]const u8 = if (i >= args.len)
        &[_][:0]const u8{"-"}
    else
        args[i..];

    var total_l: usize = 0;
    var total_w: usize = 0;
    var total_b: usize = 0;

    var wbuf: [1024]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const out = &writer.interface;

    for (files) |path| {
        var lines: usize = 0;
        var words: usize = 0;
        var bytes: usize = 0;

        if (mem.eql(u8, path, "-")) {
            try wcCount(io, .stdin(), &lines, &words, &bytes);
        } else {
            const file = Io.Dir.cwd().openFile(io, path, .{}) catch |err| {
                var ebuf: [256]u8 = undefined;
                const msg = try std.fmt.bufPrint(&ebuf, "wc: {s}: {s}\n", .{ path, @errorName(err) });
                try util.writeAll(io, .stderr(), msg);
                continue;
            };
            defer file.close(io);
            try wcCount(io, file, &lines, &words, &bytes);
        }

        total_l += lines;
        total_w += words;
        total_b += bytes;

        try printWc(out, lines, words, bytes, show_lines, show_words, show_bytes);
        if (!mem.eql(u8, path, "-")) {
            try out.print(" {s}", .{path});
        }
        try out.writeAll("\n");
    }

    if (files.len > 1) {
        try printWc(out, total_l, total_w, total_b, show_lines, show_words, show_bytes);
        try out.writeAll(" total\n");
    }
    try out.flush();
}

fn wcCount(io: Io, file: Io.File, l: *usize, w: *usize, b: *usize) !void {
    var rbuf: [8192]u8 = undefined;
    var reader: Io.File.Reader = .init(file, io, &rbuf);
    var in_word = false;
    while (true) {
        const n = reader.interface.readSliceShort(&rbuf) catch |err| return err;
        if (n == 0) break;
        b.* += n;
        for (rbuf[0..n]) |c| {
            if (c == '\n') l.* += 1;
            if (c == ' ' or c == '\t' or c == '\n' or c == '\r') {
                in_word = false;
            } else if (!in_word) {
                in_word = true;
                w.* += 1;
            }
        }
    }
}

fn printWc(out: anytype, lines: usize, words: usize, bytes: usize, sl: bool, sw: bool, sb: bool) !void {
    var first = true;
    if (sl) {
        try out.print("{d}", .{lines});
        first = false;
    }
    if (sw) {
        if (!first) try out.writeAll(" ");
        try out.print("{d}", .{words});
        first = false;
    }
    if (sb) {
        if (!first) try out.writeAll(" ");
        try out.print("{d}", .{bytes});
    }
}
