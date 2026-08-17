const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdShuf(io: Io, arena: mem.Allocator, args: []const [:0]const u8) !void {
    // shuf [FILE] or shuf -i LO-HI  — shuffle lines / numbers
    var i: usize = 1;
    var range_lo: ?u64 = null;
    var range_hi: ?u64 = null;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        const a = args[i];
        if (mem.eql(u8, a, "-i") and i + 1 < args.len) {
            i += 1;
            const r = args[i];
            if (mem.indexOfScalar(u8, r, '-')) |dash| {
                range_lo = std.fmt.parseInt(u64, r[0..dash], 10) catch null;
                range_hi = std.fmt.parseInt(u64, r[dash + 1 ..], 10) catch null;
            }
        }
    }

    var lines: std.ArrayListUnmanaged([]const u8) = .empty;
    defer {
        for (lines.items) |ln| arena.free(ln);
        lines.deinit(arena);
    }

    if (range_lo) |lo| {
        const hi = range_hi orelse lo;
        var n = lo;
        while (n <= hi) : (n += 1) {
            const s = try std.fmt.allocPrint(arena, "{d}", .{n});
            try lines.append(arena, s);
            if (n == std.math.maxInt(u64)) break;
        }
    } else {
        const path: []const u8 = if (i < args.len) args[i] else "-";
        const file = if (mem.eql(u8, path, "-"))
            Io.File.stdin()
        else
            Io.Dir.cwd().openFile(io, path, .{}) catch |err| {
                var buf: [256]u8 = undefined;
                const msg = try std.fmt.bufPrint(&buf, "shuf: {s}: {s}\n", .{ path, @errorName(err) });
                try util.writeAll(io, .stderr(), msg);
                std.process.exit(1);
            };
        defer if (!mem.eql(u8, path, "-")) file.close(io);

        var rbuf: [8192]u8 = undefined;
        var reader: Io.File.Reader = .init(file, io, &rbuf);
        while (true) {
            const line = (reader.interface.takeDelimiter('\n') catch break) orelse break;
            try lines.append(arena, try arena.dupe(u8, line));
        }
    }

    // Fisher-Yates with simple LCG seed from timestamp
    var seed: u64 = @intCast(Io.Timestamp.now(io, .real).nanoseconds);
    seed ^= 0x9E3779B97F4A7C15;
    var idx = lines.items.len;
    while (idx > 1) {
        idx -= 1;
        seed = seed *% 6364136223846793005 +% 1;
        const j = seed % (idx + 1);
        const tmp = lines.items[idx];
        lines.items[idx] = lines.items[j];
        lines.items[j] = tmp;
    }

    var wbuf: [8192]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const w = &writer.interface;
    for (lines.items) |ln| {
        try w.writeAll(ln);
        try w.writeAll("\n");
    }
    try w.flush();
}
