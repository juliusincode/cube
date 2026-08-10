const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdEcho(io: Io, args: []const [:0]const u8) !void {
    var buf: [4096]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &buf);
    const w = &writer.interface;

    var n_flag = false;
    var interpret_escapes = false; // -e
    var start: usize = 1;
    while (start < args.len and args[start].len > 0 and args[start][0] == '-') : (start += 1) {
        const a = args[start];
        if (mem.eql(u8, a, "--")) {
            start += 1;
            break;
        }
        // lone "-" is an argument, not a flag
        if (a.len == 1) break;
        for (a[1..]) |c| {
            switch (c) {
                'n' => n_flag = true,
                'e' => interpret_escapes = true,
                'E' => interpret_escapes = false,
                else => {},
            }
        }
    }

    var first = true;
    for (args[start..]) |arg| {
        if (!first) try w.writeAll(" ");
        if (interpret_escapes) {
            try writeEchoEscaped(w, arg);
        } else {
            try w.writeAll(arg);
        }
        first = false;
    }
    if (!n_flag) try w.writeAll("\n");
    try w.flush();
}

fn writeEchoEscaped(w: anytype, s: []const u8) !void {
    var i: usize = 0;
    while (i < s.len) {
        if (s[i] == '\\' and i + 1 < s.len) {
            const c = s[i + 1];
            i += 2;
            switch (c) {
                'n' => try w.writeAll("\n"),
                't' => try w.writeAll("\t"),
                'r' => try w.writeAll("\r"),
                '\\' => try w.writeAll("\\"),
                'a' => try w.writeAll("\x07"),
                'b' => try w.writeAll("\x08"),
                'f' => try w.writeAll("\x0c"),
                'v' => try w.writeAll("\x0b"),
                '0' => try w.writeAll(&.{0}),
                'c' => return, // stop output (busybox/bash)
                'x' => {
                    // \xHH
                    if (i + 1 < s.len) {
                        const hi = std.fmt.parseInt(u8, s[i .. i + 1], 16) catch {
                            try w.writeAll(&.{'\\', 'x'});
                            continue;
                        };
                        if (i + 1 < s.len) {
                            const lo = std.fmt.parseInt(u8, s[i + 1 .. i + 2], 16) catch {
                                try w.writeAll(&.{ @as(u8, @intCast(hi)) });
                                i += 1;
                                continue;
                            };
                            try w.writeAll(&.{ (hi << 4) | lo });
                            i += 2;
                        }
                    } else {
                        try w.writeAll(&.{'\\', 'x'});
                    }
                },
                else => {
                    try w.writeAll(&.{'\\', c});
                },
            }
        } else {
            try w.writeAll(s[i .. i + 1]);
            i += 1;
        }
    }
}
pub fn cmdCat(io: Io, args: []const [:0]const u8) !void {
    var number = false; // -n number all lines
    var number_nonblank = false; // -b number non-empty lines
    var squeeze = false; // -s squeeze blank lines
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        const a = args[i];
        if (mem.eql(u8, a, "--")) {
            i += 1;
            break;
        }
        if (a.len == 1) break; // "-" means stdin
        for (a[1..]) |c| {
            switch (c) {
                'n' => number = true,
                'b' => {
                    number_nonblank = true;
                    number = true; // -b implies numbering non-blank only
                },
                's' => squeeze = true,
                else => {},
            }
        }
    }

    const files: []const [:0]const u8 = if (i >= args.len)
        &[_][:0]const u8{"-"}
    else
        args[i..];

    var line_no: usize = 1;
    var prev_blank = false;

    for (files) |path| {
        if (mem.eql(u8, path, "-")) {
            try catStream(io, .stdin(), number, number_nonblank, squeeze, &line_no, &prev_blank);
            continue;
        }
        const file = Io.Dir.cwd().openFile(io, path, .{}) catch |err| {
            var ebuf: [512]u8 = undefined;
            const msg = try std.fmt.bufPrint(&ebuf, "cat: {s}: {s}\n", .{ path, @errorName(err) });
            try util.writeAll(io, .stderr(), msg);
            continue;
        };
        defer file.close(io);
        try catStream(io, file, number, number_nonblank, squeeze, &line_no, &prev_blank);
    }
}

fn catStream(
    io: Io,
    file: Io.File,
    number: bool,
    number_nonblank: bool,
    squeeze: bool,
    line_no: *usize,
    prev_blank: *bool,
) !void {
    if (!number and !squeeze) {
        try util.copyFile(io, file, .stdout());
        return;
    }

    var rbuf: [8192]u8 = undefined;
    var reader: Io.File.Reader = .init(file, io, &rbuf);
    var wbuf: [8192]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const w = &writer.interface;

    while (true) {
        const line = (reader.interface.takeDelimiter('\n') catch |err| return err) orelse break;
        const blank = line.len == 0;

        if (squeeze and blank and prev_blank.*) continue;
        prev_blank.* = blank;

        if (number) {
            if (number_nonblank and blank) {
                try w.writeAll("\n");
                continue;
            }
            try w.print("{d: >6}\t", .{line_no.*});
            line_no.* += 1;
        }
        try w.writeAll(line);
        try w.writeAll("\n");
    }
    try w.flush();
}

pub fn cmdHead(io: Io, args: []const [:0]const u8) !void {
    var lines: ?usize = null;
    var bytes: ?usize = null;
    var file_arg: ?[:0]const u8 = null;
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const a = args[i];
        if (mem.eql(u8, a, "-n") and i + 1 < args.len) {
            lines = std.fmt.parseInt(usize, args[i + 1], 10) catch 10;
            i += 1;
        } else if (a.len > 2 and a[0] == '-' and a[1] == 'n') {
            lines = std.fmt.parseInt(usize, a[2..], 10) catch 10;
        } else if (mem.eql(u8, a, "-c") and i + 1 < args.len) {
            bytes = std.fmt.parseInt(usize, args[i + 1], 10) catch 0;
            i += 1;
        } else if (a.len > 2 and a[0] == '-' and a[1] == 'c') {
            bytes = std.fmt.parseInt(usize, a[2..], 10) catch 0;
        } else if (a.len > 1 and a[0] == '-' and a[1] >= '0' and a[1] <= '9') {
            // historic: head -5 file
            lines = std.fmt.parseInt(usize, a[1..], 10) catch 10;
        } else if (a[0] != '-') {
            file_arg = a;
        }
    }
    if (lines == null and bytes == null) lines = 10;

    const file = if (file_arg) |p|
        Io.Dir.cwd().openFile(io, p, .{}) catch |err| {
            var b: [256]u8 = undefined;
            const msg = try std.fmt.bufPrint(&b, "head: {s}: {s}\n", .{ p, @errorName(err) });
            try util.writeAll(io, .stderr(), msg);
            return;
        }
    else
        Io.File.stdin();
    defer if (file_arg != null) file.close(io);

    var wbuf: [8192]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const w = &writer.interface;

    if (bytes) |nbyte| {
        var rbuf: [8192]u8 = undefined;
        var reader: Io.File.Reader = .init(file, io, &rbuf);
        var outbuf: [8192]u8 = undefined;
        var remaining = nbyte;
        while (remaining > 0) {
            const chunk = @min(remaining, outbuf.len);
            const n = reader.interface.readSliceShort(outbuf[0..chunk]) catch |err| return err;
            if (n == 0) break;
            try w.writeAll(outbuf[0..n]);
            remaining -= n;
        }
        try w.flush();
        return;
    }

    var rbuf: [4096]u8 = undefined;
    var reader: Io.File.Reader = .init(file, io, &rbuf);
    var count: usize = 0;
    const limit = lines.?;
    while (count < limit) {
        const line = (reader.interface.takeDelimiter('\n') catch |err| return err) orelse break;
        try w.writeAll(line);
        try w.writeAll("\n");
        count += 1;
    }
    try w.flush();
}

pub fn cmdTail(io: Io, arena: mem.Allocator, args: []const [:0]const u8) !void {
    var lines: ?usize = null;
    var bytes: ?usize = null;
    var file_arg: ?[:0]const u8 = null;
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const a = args[i];
        if (mem.eql(u8, a, "-n") and i + 1 < args.len) {
            lines = std.fmt.parseInt(usize, args[i + 1], 10) catch 10;
            i += 1;
        } else if (a.len > 2 and a[0] == '-' and a[1] == 'n') {
            lines = std.fmt.parseInt(usize, a[2..], 10) catch 10;
        } else if (mem.eql(u8, a, "-c") and i + 1 < args.len) {
            bytes = std.fmt.parseInt(usize, args[i + 1], 10) catch 0;
            i += 1;
        } else if (a.len > 2 and a[0] == '-' and a[1] == 'c') {
            bytes = std.fmt.parseInt(usize, a[2..], 10) catch 0;
        } else if (a.len > 1 and a[0] == '-' and a[1] >= '0' and a[1] <= '9') {
            lines = std.fmt.parseInt(usize, a[1..], 10) catch 10;
        } else if (a[0] != '-') {
            file_arg = a;
        }
    }
    if (lines == null and bytes == null) lines = 10;

    const file = if (file_arg) |p|
        Io.Dir.cwd().openFile(io, p, .{}) catch |err| {
            var b: [256]u8 = undefined;
            const msg = try std.fmt.bufPrint(&b, "tail: {s}: {s}\n", .{ p, @errorName(err) });
            try util.writeAll(io, .stderr(), msg);
            return;
        }
    else
        Io.File.stdin();
    defer if (file_arg != null) file.close(io);

    var wbuf: [8192]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const w = &writer.interface;

    if (bytes) |nbyte| {
        // Read all into memory, print last n bytes
        var data: std.ArrayListUnmanaged(u8) = .empty;
        defer data.deinit(arena);
        var rbuf: [8192]u8 = undefined;
        var reader: Io.File.Reader = .init(file, io, &rbuf);
        var outbuf: [8192]u8 = undefined;
        while (true) {
            const n = reader.interface.readSliceShort(&outbuf) catch |err| return err;
            if (n == 0) break;
            try data.appendSlice(arena, outbuf[0..n]);
        }
        const start_i = if (data.items.len > nbyte) data.items.len - nbyte else 0;
        try w.writeAll(data.items[start_i..]);
        try w.flush();
        return;
    }

    const limit = lines.?;
    var list: std.ArrayListUnmanaged([]const u8) = .empty;
    defer {
        for (list.items) |l| arena.free(l);
        list.deinit(arena);
    }

    var rbuf: [4096]u8 = undefined;
    var reader: Io.File.Reader = .init(file, io, &rbuf);
    while (true) {
        const line = (reader.interface.takeDelimiter('\n') catch |err| return err) orelse break;
        const owned = try arena.dupe(u8, line);
        try list.append(arena, owned);
        if (list.items.len > limit) {
            arena.free(list.orderedRemove(0));
        }
    }
    for (list.items) |l| {
        try w.writeAll(l);
        try w.writeAll("\n");
    }
    try w.flush();
}

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

pub fn cmdYes(io: Io, args: []const [:0]const u8) !void {
    const str = if (args.len > 1) args[1] else "y";
    var buf: [4096]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &buf);
    const w = &writer.interface;
    while (true) {
        try w.writeAll(str);
        try w.writeAll("\n");
        try w.flush();
    }
}

pub fn cmdSeq(io: Io, args: []const [:0]const u8) !void {
    if (args.len < 2) {
        try util.writeAll(io, .stderr(), "seq: missing operand\n");
        std.process.exit(1);
    }
    var start: i64 = 1;
    var step: i64 = 1;
    var end: i64 = undefined;
    if (args.len == 2) {
        end = std.fmt.parseInt(i64, args[1], 10) catch {
            try util.writeAll(io, .stderr(), "seq: invalid\n");
            std.process.exit(1);
        };
    } else if (args.len == 3) {
        start = std.fmt.parseInt(i64, args[1], 10) catch 1;
        end = std.fmt.parseInt(i64, args[2], 10) catch {
            try util.writeAll(io, .stderr(), "seq: invalid\n");
            std.process.exit(1);
        };
    } else {
        start = std.fmt.parseInt(i64, args[1], 10) catch 1;
        step = std.fmt.parseInt(i64, args[2], 10) catch 1;
        end = std.fmt.parseInt(i64, args[3], 10) catch {
            try util.writeAll(io, .stderr(), "seq: invalid\n");
            std.process.exit(1);
        };
    }
    var buf: [4096]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &buf);
    const w = &writer.interface;
    var i = start;
    while ((step > 0 and i <= end) or (step < 0 and i >= end)) : (i += step) {
        try w.print("{d}\n", .{i});
    }
    try w.flush();
}

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

pub fn cmdGrep(io: Io, arena: mem.Allocator, args: []const [:0]const u8) !void {
    // Fixed-string grep (like grep -F) with common flags:
    //   -i ignore case
    //   -v invert match
    //   -n line numbers
    //   -r/-R recursive directories
    //   -l files with matches only
    //   -c count matches per file
    //   -q quiet (exit status only)
    //   -H / -h force/suppress filename prefix
    var ignore_case = false;
    var invert = false;
    var line_num = false;
    var recursive = false;
    var files_with_matches = false;
    var count_only = false;
    var quiet = false;
    var show_filename: ?bool = null; // null = auto

    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        const a = args[i];
        if (mem.eql(u8, a, "--")) {
            i += 1;
            break;
        }
        if (mem.eql(u8, a, "--help")) {
            try util.writeAll(io, .stdout(),
                \\Usage: grep [-ivnrlcqHh] PATTERN [FILE]...
                \\  -i  ignore case
                \\  -v  invert match
                \\  -n  print line number
                \\  -r  recursive
                \\  -l  print only file names with matches
                \\  -c  print count of matching lines
                \\  -q  quiet; exit status only
                \\  -H  always print filename
                \\  -h  never print filename
                \\
                \\Fixed-string matching (substring), not full regex.
                \\
            );
            return;
        }
        for (a[1..]) |c| {
            switch (c) {
                'i' => ignore_case = true,
                'v' => invert = true,
                'n' => line_num = true,
                'r', 'R' => recursive = true,
                'l' => files_with_matches = true,
                'c' => count_only = true,
                'q' => quiet = true,
                'H' => show_filename = true,
                'h' => show_filename = false,
                'F', 'e' => {}, // fixed string / pattern already default
                else => {},
            }
        }
    }

    if (i >= args.len) {
        try util.writeAll(io, .stderr(), "grep: missing pattern\n");
        std.process.exit(2);
    }
    const pattern = args[i];
    i += 1;

    const files: []const [:0]const u8 = if (i >= args.len)
        &[_][:0]const u8{"-"} // stdin
    else
        args[i..];

    const multi = files.len > 1 or recursive;
    const prefix = show_filename orelse multi;

    var any_match = false;
    var had_error = false;

    for (files) |path| {
        if (mem.eql(u8, path, "-")) {
            const m = try grepFile(io, arena, .stdin(), null, pattern, .{
                .ignore_case = ignore_case,
                .invert = invert,
                .line_num = line_num,
                .files_with_matches = files_with_matches,
                .count_only = count_only,
                .quiet = quiet,
                .show_filename = false,
            });
            if (m) any_match = true;
            continue;
        }

        const st = Io.Dir.cwd().statFile(io, path, .{}) catch |err| {
            if (!quiet) {
                var buf: [512]u8 = undefined;
                const msg = try std.fmt.bufPrint(&buf, "grep: {s}: {s}\n", .{ path, @errorName(err) });
                try util.writeAll(io, .stderr(), msg);
            }
            had_error = true;
            continue;
        };

        if (st.kind == .directory) {
            if (!recursive) {
                if (!quiet) {
                    var buf: [512]u8 = undefined;
                    const msg = try std.fmt.bufPrint(&buf, "grep: {s}: Is a directory\n", .{path});
                    try util.writeAll(io, .stderr(), msg);
                }
                had_error = true;
                continue;
            }
            const m = try grepDir(io, arena, path, pattern, .{
                .ignore_case = ignore_case,
                .invert = invert,
                .line_num = line_num,
                .files_with_matches = files_with_matches,
                .count_only = count_only,
                .quiet = quiet,
                .show_filename = true,
            });
            if (m) any_match = true;
            continue;
        }

        const file = Io.Dir.cwd().openFile(io, path, .{}) catch |err| {
            if (!quiet) {
                var buf: [512]u8 = undefined;
                const msg = try std.fmt.bufPrint(&buf, "grep: {s}: {s}\n", .{ path, @errorName(err) });
                try util.writeAll(io, .stderr(), msg);
            }
            had_error = true;
            continue;
        };
        defer file.close(io);

        const m = try grepFile(io, arena, file, path, pattern, .{
            .ignore_case = ignore_case,
            .invert = invert,
            .line_num = line_num,
            .files_with_matches = files_with_matches,
            .count_only = count_only,
            .quiet = quiet,
            .show_filename = prefix,
        });
        if (m) any_match = true;
    }

    if (had_error and !any_match) std.process.exit(2);
    if (!any_match) std.process.exit(1);
}

const GrepOpts = struct {
    ignore_case: bool,
    invert: bool,
    line_num: bool,
    files_with_matches: bool,
    count_only: bool,
    quiet: bool,
    show_filename: bool,
};

fn grepDir(io: Io, arena: mem.Allocator, dir_path: []const u8, pattern: []const u8, opts: GrepOpts) anyerror!bool {
    var dir = Io.Dir.cwd().openDir(io, dir_path, .{ .iterate = true }) catch return false;
    defer dir.close(io);

    var any = false;
    var it = dir.iterate();
    while (try it.next(io)) |entry| {
        if (mem.eql(u8, entry.name, ".") or mem.eql(u8, entry.name, "..")) continue;
        const child = try std.fmt.allocPrint(arena, "{s}/{s}", .{ dir_path, entry.name });
        defer arena.free(child);

        if (entry.kind == .directory) {
            if (try grepDir(io, arena, child, pattern, opts)) any = true;
            continue;
        }
        if (entry.kind != .file and entry.kind != .sym_link) continue;

        const file = Io.Dir.cwd().openFile(io, child, .{}) catch continue;
        defer file.close(io);
        if (try grepFile(io, arena, file, child, pattern, opts)) any = true;
    }
    return any;
}

fn grepFile(
    io: Io,
    arena: mem.Allocator,
    file: Io.File,
    path: ?[]const u8,
    pattern: []const u8,
    opts: GrepOpts,
) !bool {
    _ = arena;
    var rbuf: [8192]u8 = undefined;
    var reader: Io.File.Reader = .init(file, io, &rbuf);

    var wbuf: [8192]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const w = &writer.interface;

    var line_no: usize = 0;
    var match_count: usize = 0;
    var any = false;

    while (true) {
        const line = (reader.interface.takeDelimiter('\n') catch |err| return err) orelse break;
        line_no += 1;

        const matched = lineMatches(line, pattern, opts.ignore_case);
        const selected = if (opts.invert) !matched else matched;
        if (!selected) continue;

        any = true;
        match_count += 1;

        if (opts.quiet) continue;
        if (opts.files_with_matches) {
            // print once later
            continue;
        }
        if (opts.count_only) continue;

        if (opts.show_filename) {
            if (path) |p| {
                try w.writeAll(p);
                try w.writeAll(":");
            }
        }
        if (opts.line_num) {
            try w.print("{d}:", .{line_no});
        }
        try w.writeAll(line);
        try w.writeAll("\n");
    }

    if (opts.quiet) {
        return any;
    }
    if (opts.files_with_matches) {
        if (any) {
            if (path) |p| {
                try w.writeAll(p);
                try w.writeAll("\n");
            }
        }
        try w.flush();
        return any;
    }
    if (opts.count_only) {
        if (opts.show_filename) {
            if (path) |p| {
                try w.writeAll(p);
                try w.writeAll(":");
            }
        }
        try w.print("{d}\n", .{match_count});
        try w.flush();
        return any;
    }
    try w.flush();
    return any;
}

fn lineMatches(line: []const u8, pattern: []const u8, ignore_case: bool) bool {
    if (pattern.len == 0) return true;
    if (!ignore_case) {
        return mem.indexOf(u8, line, pattern) != null;
    }
    // case-insensitive substring search
    if (pattern.len > line.len) return false;
    var i: usize = 0;
    while (i + pattern.len <= line.len) : (i += 1) {
        if (eqlIgnoreCase(line[i .. i + pattern.len], pattern)) return true;
    }
    return false;
}

fn eqlIgnoreCase(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |x, y| {
        if (std.ascii.toLower(x) != std.ascii.toLower(y)) return false;
    }
    return true;
}


pub fn cmdSort(io: Io, arena: mem.Allocator, args: []const [:0]const u8) !void {
    var numeric = false;
    var reverse = false;
    var unique = false;
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        const a = args[i];
        if (mem.eql(u8, a, "--")) {
            i += 1;
            break;
        }
        for (a[1..]) |c| {
            switch (c) {
                'n' => numeric = true,
                'r' => reverse = true,
                'u' => unique = true,
                else => {},
            }
        }
    }

    var lines: std.ArrayListUnmanaged([]const u8) = .empty;
    defer {
        for (lines.items) |l| arena.free(l);
        lines.deinit(arena);
    }

    const readAll = struct {
        fn f(io_: Io, arena_: mem.Allocator, file: Io.File, list: *std.ArrayListUnmanaged([]const u8)) !void {
            var rbuf: [8192]u8 = undefined;
            var reader: Io.File.Reader = .init(file, io_, &rbuf);
            while (true) {
                const line = (reader.interface.takeDelimiter('\n') catch |err| return err) orelse break;
                try list.append(arena_, try arena_.dupe(u8, line));
            }
        }
    }.f;

    if (i >= args.len) {
        try readAll(io, arena, .stdin(), &lines);
    } else {
        for (args[i..]) |path| {
            if (mem.eql(u8, path, "-")) {
                try readAll(io, arena, .stdin(), &lines);
                continue;
            }
            const file = Io.Dir.cwd().openFile(io, path, .{}) catch |err| {
                var buf: [256]u8 = undefined;
                const msg = try std.fmt.bufPrint(&buf, "sort: {s}: {s}\n", .{ path, @errorName(err) });
                try util.writeAll(io, .stderr(), msg);
                continue;
            };
            defer file.close(io);
            try readAll(io, arena, file, &lines);
        }
    }

    if (numeric) {
        const Ctx = struct {
            fn less(_: void, a: []const u8, b: []const u8) bool {
                const na = std.fmt.parseFloat(f64, a) catch std.math.nan(f64);
                const nb = std.fmt.parseFloat(f64, b) catch std.math.nan(f64);
                if (std.math.isNan(na) and std.math.isNan(nb)) return mem.order(u8, a, b) == .lt;
                if (std.math.isNan(na)) return false;
                if (std.math.isNan(nb)) return true;
                return na < nb;
            }
        };
        std.mem.sort([]const u8, lines.items, {}, Ctx.less);
    } else {
        std.mem.sort([]const u8, lines.items, {}, struct {
            fn less(_: void, a: []const u8, b: []const u8) bool {
                return mem.order(u8, a, b) == .lt;
            }
        }.less);
    }

    if (reverse) {
        mem.reverse([]const u8, lines.items);
    }

    var wbuf: [8192]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const w = &writer.interface;

    var prev: ?[]const u8 = null;
    for (lines.items) |line| {
        if (unique) {
            if (prev) |p| {
                if (mem.eql(u8, p, line)) continue;
            }
            prev = line;
        }
        try w.writeAll(line);
        try w.writeAll("\n");
    }
    try w.flush();
}

pub fn cmdCut(io: Io, args: []const [:0]const u8) !void {
    var delimiter: u8 = '\t';
    var fields_spec: ?[]const u8 = null;
    var chars_spec: ?[]const u8 = null;
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const a = args[i];
        if (mem.eql(u8, a, "-d") and i + 1 < args.len) {
            delimiter = if (args[i + 1].len > 0) args[i + 1][0] else '\t';
            i += 1;
        } else if (mem.eql(u8, a, "-f") and i + 1 < args.len) {
            fields_spec = args[i + 1];
            i += 1;
        } else if (mem.eql(u8, a, "-c") and i + 1 < args.len) {
            chars_spec = args[i + 1];
            i += 1;
        } else if (a.len > 2 and a[0] == '-' and a[1] == 'd') {
            delimiter = a[2];
        } else if (a.len > 2 and a[0] == '-' and a[1] == 'f') {
            fields_spec = a[2..];
        } else if (a.len > 2 and a[0] == '-' and a[1] == 'c') {
            chars_spec = a[2..];
        } else if (a[0] != '-') {
            break;
        }
    }

    if (fields_spec == null and chars_spec == null) {
        try util.writeAll(io, .stderr(), "cut: you must specify a list of bytes, characters, or fields\n");
        std.process.exit(1);
    }

    const files: []const [:0]const u8 = if (i >= args.len)
        &[_][:0]const u8{"-"}
    else
        args[i..];

    var wbuf: [8192]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const w = &writer.interface;

    for (files) |path| {
        const file = if (mem.eql(u8, path, "-"))
            Io.File.stdin()
        else
            Io.Dir.cwd().openFile(io, path, .{}) catch |err| {
                var buf: [256]u8 = undefined;
                const msg = try std.fmt.bufPrint(&buf, "cut: {s}: {s}\n", .{ path, @errorName(err) });
                try util.writeAll(io, .stderr(), msg);
                continue;
            };
        defer if (!mem.eql(u8, path, "-")) file.close(io);

        var rbuf: [8192]u8 = undefined;
        var reader: Io.File.Reader = .init(file, io, &rbuf);
        while (true) {
            const line = (reader.interface.takeDelimiter('\n') catch |err| return err) orelse break;
            if (chars_spec) |spec| {
                try cutChars(w, line, spec);
            } else if (fields_spec) |spec| {
                try cutFields(w, line, delimiter, spec);
            }
            try w.writeAll("\n");
        }
    }
    try w.flush();
}

fn cutChars(w: anytype, line: []const u8, spec: []const u8) !void {
    var bits: std.StaticBitSet(4096) = .initEmpty();
    // parse into static set
    var it = mem.splitScalar(u8, spec, ',');
    while (it.next()) |part| {
        if (mem.indexOfScalar(u8, part, '-')) |dash| {
            const lo = std.fmt.parseInt(usize, part[0..dash], 10) catch continue;
            const hi_s = part[dash + 1 ..];
            const hi = if (hi_s.len == 0) line.len else std.fmt.parseInt(usize, hi_s, 10) catch continue;
            var n = lo;
            while (n <= hi and n <= line.len) : (n += 1) {
                if (n > 0 and n <= 4095) bits.set(n);
            }
        } else {
            const n = std.fmt.parseInt(usize, part, 10) catch continue;
            if (n > 0 and n <= line.len and n <= 4095) bits.set(n);
        }
    }
    var idx: usize = 1;
    while (idx <= line.len) : (idx += 1) {
        if (bits.isSet(idx)) try w.writeAll(line[idx - 1 .. idx]);
    }
}

fn cutFields(w: anytype, line: []const u8, delim: u8, spec: []const u8) !void {
    var selected: [256]bool = [_]bool{false} ** 256;
    var it = mem.splitScalar(u8, spec, ',');
    while (it.next()) |part| {
        if (mem.indexOfScalar(u8, part, '-')) |dash| {
            const lo = std.fmt.parseInt(usize, part[0..dash], 10) catch continue;
            const hi_s = part[dash + 1 ..];
            const hi = if (hi_s.len == 0) 255 else std.fmt.parseInt(usize, hi_s, 10) catch continue;
            var n = lo;
            while (n <= hi and n < 256) : (n += 1) {
                if (n > 0) selected[n] = true;
            }
        } else {
            const n = std.fmt.parseInt(usize, part, 10) catch continue;
            if (n > 0 and n < 256) selected[n] = true;
        }
    }

    var field: usize = 1;
    var start: usize = 0;
    var first_out = true;
    var pos: usize = 0;
    while (pos <= line.len) : (pos += 1) {
        const at_end = pos == line.len;
        const is_delim = !at_end and line[pos] == delim;
        if (is_delim or at_end) {
            if (field < 256 and selected[field]) {
                if (!first_out) try w.writeAll(&.{delim});
                try w.writeAll(line[start..pos]);
                first_out = false;
            }
            field += 1;
            start = pos + 1;
            if (at_end) break;
        }
    }
}

pub fn cmdUniq(io: Io, arena: mem.Allocator, args: []const [:0]const u8) !void {
    _ = arena;
    var count = false;
    var repeated = false;
    var unique_only = false;
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        const a = args[i];
        if (mem.eql(u8, a, "--")) {
            i += 1;
            break;
        }
        for (a[1..]) |c| {
            switch (c) {
                'c' => count = true,
                'd' => repeated = true,
                'u' => unique_only = true,
                else => {},
            }
        }
    }

    const path: ?[:0]const u8 = if (i < args.len) args[i] else null;
    const file = if (path) |p|
        Io.Dir.cwd().openFile(io, p, .{}) catch |err| {
            var buf: [256]u8 = undefined;
            const msg = try std.fmt.bufPrint(&buf, "uniq: {s}: {s}\n", .{ p, @errorName(err) });
            try util.writeAll(io, .stderr(), msg);
            return;
        }
    else
        Io.File.stdin();
    defer if (path != null) file.close(io);

    var wbuf: [8192]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const w = &writer.interface;

    var rbuf: [8192]u8 = undefined;
    var reader: Io.File.Reader = .init(file, io, &rbuf);

    var prev_buf: [8192]u8 = undefined;
    var prev_len: usize = 0;
    var have_prev = false;
    var run: usize = 0;

    const flush_run = struct {
        fn f(w_: anytype, line: []const u8, run_: usize, count_: bool, repeated_: bool, unique_only_: bool) !void {
            if (run_ == 0) return;
            if (repeated_ and run_ < 2) return;
            if (unique_only_ and run_ != 1) return;
            if (count_) try w_.print("{d: >7} ", .{run_});
            try w_.writeAll(line);
            try w_.writeAll("\n");
        }
    }.f;

    while (true) {
        const line = (reader.interface.takeDelimiter('\n') catch |err| return err) orelse break;
        if (have_prev and mem.eql(u8, prev_buf[0..prev_len], line)) {
            run += 1;
            continue;
        }
        if (have_prev) {
            try flush_run(w, prev_buf[0..prev_len], run, count, repeated, unique_only);
        }
        const copy_len = @min(line.len, prev_buf.len);
        @memcpy(prev_buf[0..copy_len], line[0..copy_len]);
        prev_len = copy_len;
        have_prev = true;
        run = 1;
    }
    if (have_prev) {
        try flush_run(w, prev_buf[0..prev_len], run, count, repeated, unique_only);
    }
    try w.flush();
}

pub fn cmdRev(io: Io, args: []const [:0]const u8) !void {
    const files: []const [:0]const u8 = if (args.len <= 1)
        &[_][:0]const u8{"-"}
    else
        args[1..];

    var wbuf: [8192]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const w = &writer.interface;

    for (files) |path| {
        const file = if (mem.eql(u8, path, "-"))
            Io.File.stdin()
        else
            Io.Dir.cwd().openFile(io, path, .{}) catch |err| {
                var buf: [256]u8 = undefined;
                const msg = try std.fmt.bufPrint(&buf, "rev: {s}: {s}\n", .{ path, @errorName(err) });
                try util.writeAll(io, .stderr(), msg);
                continue;
            };
        defer if (!mem.eql(u8, path, "-")) file.close(io);

        var rbuf: [8192]u8 = undefined;
        var reader: Io.File.Reader = .init(file, io, &rbuf);
        while (true) {
            const line = (reader.interface.takeDelimiter('\n') catch |err| return err) orelse break;
            // reverse bytes
            var j: usize = line.len;
            while (j > 0) {
                j -= 1;
                try w.writeAll(line[j .. j + 1]);
            }
            try w.writeAll("\n");
        }
    }
    try w.flush();
}

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


pub fn cmdSed(io: Io, args: []const [:0]const u8) !void {
    // sed [ -n ] 's/pat/repl/[g]' [FILE]...
    // Fixed-string substitute only (no full regex).
    var quiet = false; // -n
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        const a = args[i];
        if (mem.eql(u8, a, "--")) {
            i += 1;
            break;
        }
        for (a[1..]) |c| {
            if (c == 'n') quiet = true;
        }
    }
    if (i >= args.len) {
        try util.writeAll(io, .stderr(), "sed: missing script\n");
        std.process.exit(1);
    }
    const script = args[i];
    i += 1;

    var pat: []const u8 = "";
    var repl: []const u8 = "";
    var global = false;
    if (!parseSedSubstitute(script, &pat, &repl, &global)) {
        try util.writeAll(io, .stderr(), "sed: unsupported script (only s/// supported)\n");
        std.process.exit(1);
    }

    const files: []const [:0]const u8 = if (i >= args.len)
        &[_][:0]const u8{"-"}
    else
        args[i..];

    var wbuf: [8192]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const w = &writer.interface;

    for (files) |path| {
        const file = if (mem.eql(u8, path, "-"))
            Io.File.stdin()
        else
            Io.Dir.cwd().openFile(io, path, .{}) catch |err| {
                var buf: [256]u8 = undefined;
                const msg = try std.fmt.bufPrint(&buf, "sed: {s}: {s}\n", .{ path, @errorName(err) });
                try util.writeAll(io, .stderr(), msg);
                continue;
            };
        defer if (!mem.eql(u8, path, "-")) file.close(io);

        var rbuf: [8192]u8 = undefined;
        var reader: Io.File.Reader = .init(file, io, &rbuf);
        while (true) {
            const line = (reader.interface.takeDelimiter('\n') catch |err| return err) orelse break;
            var out_buf: [16384]u8 = undefined;
            const out = sedReplace(line, pat, repl, global, &out_buf) catch line;
            if (!quiet) {
                try w.writeAll(out);
                try w.writeAll("\n");
            }
        }
    }
    try w.flush();
}

fn parseSedSubstitute(script: []const u8, pat: *[]const u8, repl: *[]const u8, global: *bool) bool {
    // Accept s/pat/repl/ or s/pat/repl/g  (delimiter is first char after s)
    if (script.len < 4 or script[0] != 's') return false;
    const delim = script[1];
    const rest = script[2..];
    const end_pat = mem.indexOfScalar(u8, rest, delim) orelse return false;
    pat.* = rest[0..end_pat];
    const after_pat = rest[end_pat + 1 ..];
    const end_repl = mem.indexOfScalar(u8, after_pat, delim) orelse return false;
    repl.* = after_pat[0..end_repl];
    const flags = after_pat[end_repl + 1 ..];
    global.* = mem.indexOfScalar(u8, flags, 'g') != null;
    return true;
}

fn sedReplace(line: []const u8, pat: []const u8, repl: []const u8, global: bool, out: []u8) ![]const u8 {
    if (pat.len == 0) {
        if (line.len + repl.len > out.len) return error.NoSpace;
        @memcpy(out[0..line.len], line);
        return out[0..line.len];
    }
    var o: usize = 0;
    var i: usize = 0;
    var replaced_once = false;
    while (i < line.len) {
        if ((!replaced_once or global) and i + pat.len <= line.len and mem.eql(u8, line[i .. i + pat.len], pat)) {
            if (o + repl.len > out.len) return error.NoSpace;
            @memcpy(out[o .. o + repl.len], repl);
            o += repl.len;
            i += pat.len;
            replaced_once = true;
            if (!global) {
                // copy rest
                const rest = line[i..];
                if (o + rest.len > out.len) return error.NoSpace;
                @memcpy(out[o .. o + rest.len], rest);
                o += rest.len;
                break;
            }
        } else {
            if (o + 1 > out.len) return error.NoSpace;
            out[o] = line[i];
            o += 1;
            i += 1;
        }
    }
    return out[0..o];
}


pub fn cmdTee(io: Io, args: []const [:0]const u8) !void {
    // tee [-a] [FILE]...
    var append = false;
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        const a = args[i];
        if (mem.eql(u8, a, "--")) {
            i += 1;
            break;
        }
        for (a[1..]) |c| {
            if (c == 'a') append = true;
        }
    }

    const paths = args[i..];
    var files: [16]?Io.File = [_]?Io.File{null} ** 16;
    var offsets: [16]u64 = [_]u64{0} ** 16;
    var nfiles: usize = 0;

    for (paths) |path| {
        if (nfiles >= files.len) break;
        const f = Io.Dir.cwd().createFile(io, path, .{ .truncate = !append }) catch |err| {
            var buf: [256]u8 = undefined;
            const msg = try std.fmt.bufPrint(&buf, "tee: {s}: {s}\n", .{ path, @errorName(err) });
            try util.writeAll(io, .stderr(), msg);
            continue;
        };
        if (append) {
            offsets[nfiles] = f.length(io) catch 0;
        }
        files[nfiles] = f;
        nfiles += 1;
    }
    defer {
        var fi: usize = 0;
        while (fi < nfiles) : (fi += 1) {
            if (files[fi]) |f| f.close(io);
        }
    }

    var rbuf: [8192]u8 = undefined;
    var reader: Io.File.Reader = .init(.stdin(), io, &rbuf);
    var outbuf: [8192]u8 = undefined;

    var wbuf: [8192]u8 = undefined;
    var stdout_w: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const out = &stdout_w.interface;

    while (true) {
        const n = reader.interface.readSliceShort(&outbuf) catch |err| return err;
        if (n == 0) break;
        try out.writeAll(outbuf[0..n]);
        var fi: usize = 0;
        while (fi < nfiles) : (fi += 1) {
            if (files[fi]) |f| {
                if (append) {
                    f.writePositionalAll(io, outbuf[0..n], offsets[fi]) catch {};
                    offsets[fi] += n;
                } else {
                    var fbuf: [8192]u8 = undefined;
                    var fw: Io.File.Writer = .initStreaming(f, io, &fbuf);
                    fw.interface.writeAll(outbuf[0..n]) catch {};
                    fw.interface.flush() catch {};
                }
            }
        }
    }
    try out.flush();
}

pub fn cmdXargs(io: Io, arena: mem.Allocator, args: []const [:0]const u8) !void {
    // xargs [ -n N ] [ -d delim ] [command [initial-args...]]
    // Reads stdin items and runs command via posix.exec — without full spawn API,
    // we print the would-be command lines when command is echo-like, OR
    // use std.process.Child if available in 0.16.
    var max_args: usize = 32;
    var delim: u8 = '\n'; // default: newline (busybox often uses whitespace)
    var whitespace_split = true;
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        const a = args[i];
        if (mem.eql(u8, a, "--")) {
            i += 1;
            break;
        }
        if (mem.eql(u8, a, "-n") and i + 1 < args.len) {
            max_args = std.fmt.parseInt(usize, args[i + 1], 10) catch 32;
            i += 1;
        } else if (mem.eql(u8, a, "-0") or mem.eql(u8, a, "-z")) {
            delim = 0;
            whitespace_split = false;
        } else if (mem.eql(u8, a, "-d") and i + 1 < args.len) {
            delim = if (args[i + 1].len > 0) args[i + 1][0] else '\n';
            whitespace_split = false;
            i += 1;
        }
    }

    const cmd: []const [:0]const u8 = if (i < args.len) args[i..] else &[_][:0]const u8{"echo"};

    // Collect tokens from stdin
    var tokens: std.ArrayListUnmanaged([]const u8) = .empty;
    defer {
        for (tokens.items) |tok| arena.free(tok);
        tokens.deinit(arena);
    }

    var rbuf: [8192]u8 = undefined;
    var reader: Io.File.Reader = .init(.stdin(), io, &rbuf);
    var acc: std.ArrayListUnmanaged(u8) = .empty;
    defer acc.deinit(arena);

    var outbuf: [4096]u8 = undefined;
    while (true) {
        const n = reader.interface.readSliceShort(&outbuf) catch |err| return err;
        if (n == 0) break;
        for (outbuf[0..n]) |c| {
            const is_delim = if (whitespace_split)
                (c == ' ' or c == '\t' or c == '\n' or c == '\r')
            else
                (c == delim);
            if (is_delim) {
                if (acc.items.len > 0) {
                    try tokens.append(arena, try arena.dupe(u8, acc.items));
                    acc.clearRetainingCapacity();
                }
            } else {
                try acc.append(arena, c);
            }
        }
    }
    if (acc.items.len > 0) {
        try tokens.append(arena, try arena.dupe(u8, acc.items));
    }

    // Execute in batches using process.Child if available
    var t: usize = 0;
    while (t < tokens.items.len) {
        const batch_end = @min(t + max_args, tokens.items.len);
        try runXargsBatch(io, arena, cmd, tokens.items[t..batch_end]);
        t = batch_end;
    }
}

fn runXargsBatch(io: Io, arena: mem.Allocator, cmd: []const [:0]const u8, batch: []const []const u8) !void {
    var argv_list: std.ArrayListUnmanaged([]const u8) = .empty;
    defer argv_list.deinit(arena);
    for (cmd) |c| try argv_list.append(arena, c);
    for (batch) |b| try argv_list.append(arena, b);

    var child = process.spawn(io, .{
        .argv = argv_list.items,
        .stdin = .ignore,
        .stdout = .inherit,
        .stderr = .inherit,
    }) catch |err| {
        var buf: [256]u8 = undefined;
        const msg = try std.fmt.bufPrint(&buf, "xargs: {s}: {s}\n", .{ cmd[0], @errorName(err) });
        try util.writeAll(io, .stderr(), msg);
        return;
    };
    _ = child.wait(io) catch {};
}


test "eqlIgnoreCase" {
    try std.testing.expect(eqlIgnoreCase("abc", "ABC"));
    try std.testing.expect(eqlIgnoreCase("AbC", "aBc"));
    try std.testing.expect(!eqlIgnoreCase("abc", "abd"));
    try std.testing.expect(!eqlIgnoreCase("abc", "ab"));
    try std.testing.expect(eqlIgnoreCase("", ""));
}

test "lineMatches case sensitive" {
    try std.testing.expect(lineMatches("hello world", "world", false));
    try std.testing.expect(lineMatches("hello world", "hello", false));
    try std.testing.expect(!lineMatches("hello world", "WORLD", false));
    try std.testing.expect(!lineMatches("hello", "hello!", false));
    try std.testing.expect(lineMatches("anything", "", false));
}

test "lineMatches case insensitive" {
    try std.testing.expect(lineMatches("Hello World", "world", true));
    try std.testing.expect(lineMatches("Hello World", "HELLO", true));
    try std.testing.expect(lineMatches("FOO", "foo", true));
    try std.testing.expect(!lineMatches("foo", "bar", true));
    try std.testing.expect(!lineMatches("fo", "foo", true));
}

test "writeEchoEscaped newlines and tabs" {
    var list: std.ArrayListUnmanaged(u8) = .empty;
    defer list.deinit(std.testing.allocator);
    const W = struct {
        list: *std.ArrayListUnmanaged(u8),
        alloc: std.mem.Allocator,
        pub fn writeAll(self: *@This(), data: []const u8) !void {
            try self.list.appendSlice(self.alloc, data);
        }
    };
    var w: W = .{ .list = &list, .alloc = std.testing.allocator };
    try writeEchoEscaped(&w, "a\\nb\\tc");
    try std.testing.expectEqualStrings("a\nb\tc", list.items);
}

test "writeEchoEscaped stop with c" {
    var list: std.ArrayListUnmanaged(u8) = .empty;
    defer list.deinit(std.testing.allocator);
    const W = struct {
        list: *std.ArrayListUnmanaged(u8),
        alloc: std.mem.Allocator,
        pub fn writeAll(self: *@This(), data: []const u8) !void {
            try self.list.appendSlice(self.alloc, data);
        }
    };
    var w: W = .{ .list = &list, .alloc = std.testing.allocator };
    try writeEchoEscaped(&w, "hi\\cIGNORE");
    try std.testing.expectEqualStrings("hi", list.items);
}

test "cutFields extracts selected fields" {
    var list: std.ArrayListUnmanaged(u8) = .empty;
    defer list.deinit(std.testing.allocator);
    const W = struct {
        list: *std.ArrayListUnmanaged(u8),
        alloc: std.mem.Allocator,
        pub fn writeAll(self: *@This(), data: []const u8) !void {
            try self.list.appendSlice(self.alloc, data);
        }
    };
    var w: W = .{ .list = &list, .alloc = std.testing.allocator };
    try cutFields(&w, "a:b:c:d", ':', "1,3");
    try std.testing.expectEqualStrings("a:c", list.items);
}

test "cutFields range" {
    var list: std.ArrayListUnmanaged(u8) = .empty;
    defer list.deinit(std.testing.allocator);
    const W = struct {
        list: *std.ArrayListUnmanaged(u8),
        alloc: std.mem.Allocator,
        pub fn writeAll(self: *@This(), data: []const u8) !void {
            try self.list.appendSlice(self.alloc, data);
        }
    };
    var w: W = .{ .list = &list, .alloc = std.testing.allocator };
    try cutFields(&w, "a:b:c:d", ':', "2-4");
    try std.testing.expectEqualStrings("b:c:d", list.items);
}

test "cutChars range" {
    var list: std.ArrayListUnmanaged(u8) = .empty;
    defer list.deinit(std.testing.allocator);
    const W = struct {
        list: *std.ArrayListUnmanaged(u8),
        alloc: std.mem.Allocator,
        pub fn writeAll(self: *@This(), data: []const u8) !void {
            try self.list.appendSlice(self.alloc, data);
        }
    };
    var w: W = .{ .list = &list, .alloc = std.testing.allocator };
    try cutChars(&w, "abcdef", "2-4");
    try std.testing.expectEqualStrings("bcd", list.items);
}

test "parseSedSubstitute" {
    var pat: []const u8 = undefined;
    var repl: []const u8 = undefined;
    var g: bool = false;
    try std.testing.expect(parseSedSubstitute("s/foo/bar/", &pat, &repl, &g));
    try std.testing.expectEqualStrings("foo", pat);
    try std.testing.expectEqualStrings("bar", repl);
    try std.testing.expect(!g);
    try std.testing.expect(parseSedSubstitute("s|a|b|g", &pat, &repl, &g));
    try std.testing.expectEqualStrings("a", pat);
    try std.testing.expectEqualStrings("b", repl);
    try std.testing.expect(g);
}

test "sedReplace once and global" {
    var buf: [128]u8 = undefined;
    const a = try sedReplace("foo foo", "foo", "x", false, &buf);
    try std.testing.expectEqualStrings("x foo", a);
    const b = try sedReplace("foo foo", "foo", "x", true, &buf);
    try std.testing.expectEqualStrings("x x", b);
}
