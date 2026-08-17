const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

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
