const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");
const common = @import("common.zig");

pub fn cmdDu(io: Io, arena: mem.Allocator, args: []const [:0]const u8) !void {
    var human = false;
    var summarize = false;
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        const a = args[i];
        if (mem.eql(u8, a, "--")) {
            i += 1;
            break;
        }
        for (a[1..]) |c| {
            switch (c) {
                'h' => human = true,
                's' => summarize = true,
                else => {},
            }
        }
    }
    const paths: []const [:0]const u8 = if (i >= args.len)
        &[_][:0]const u8{"."}
    else
        args[i..];

    var wbuf: [4096]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const w = &writer.interface;

    for (paths) |path| {
        const total = try duWalk(io, arena, w, path, human, summarize);
        if (summarize) {
            try printDuSize(w, total, human);
            try w.print("\t{s}\n", .{path});
        }
    }
    try w.flush();
}

fn duWalk(
    io: Io,
    arena: mem.Allocator,
    w: anytype,
    path: []const u8,
    human: bool,
    summarize: bool,
) anyerror!u64 {
    const st = Io.Dir.cwd().statFile(io, path, .{ .follow_symlinks = false }) catch |err| {
        var buf: [256]u8 = undefined;
        const msg = try std.fmt.bufPrint(&buf, "du: {s}: {s}\n", .{ path, @errorName(err) });
        try util.writeAll(io, .stderr(), msg);
        return 0;
    };

    var total: u64 = st.size;

    if (st.kind == .directory) {
        var dir = Io.Dir.cwd().openDir(io, path, .{ .iterate = true }) catch return total;
        defer dir.close(io);
        var it = dir.iterate();
        while (try it.next(io)) |entry| {
            if (mem.eql(u8, entry.name, ".") or mem.eql(u8, entry.name, "..")) continue;
            const child = if (mem.eql(u8, path, "."))
                try std.fmt.allocPrint(arena, "./{s}", .{entry.name})
            else
                try std.fmt.allocPrint(arena, "{s}/{s}", .{ path, entry.name });
            defer arena.free(child);
            total += try duWalk(io, arena, w, child, human, summarize);
        }
        if (!summarize) {
            try printDuSize(w, total, human);
            try w.print("\t{s}\n", .{path});
        }
    }
    return total;
}

fn printDuSize(w: anytype, size: u64, human: bool) !void {
    if (human) {
        var buf: [32]u8 = undefined;
        const s = common.formatHumanSize(&buf, size);
        try w.writeAll(s);
    } else {
        // 512-byte blocks like traditional du, or 1024? BusyBox often uses 512 or -k.
        // Use 1024-byte blocks for simplicity.
        try w.print("{d}", .{(size + 1023) / 1024});
    }
}
