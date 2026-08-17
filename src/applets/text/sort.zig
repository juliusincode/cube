const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

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
