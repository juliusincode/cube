const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdRealpath(io: Io, arena: mem.Allocator, args: []const [:0]const u8) !void {
    // realpath [FILE]...  — resolve to absolute path (best-effort)
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {}
    if (i >= args.len) {
        try util.writeAll(io, .stderr(), "realpath: missing operand\n");
        std.process.exit(1);
    }

    var wbuf: [Io.Dir.max_path_bytes + 16]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const w = &writer.interface;

    for (args[i..]) |path| {
        const resolved = resolvePath(io, arena, path) catch |err| {
            var buf: [256]u8 = undefined;
            const msg = try std.fmt.bufPrint(&buf, "realpath: {s}: {s}\n", .{ path, @errorName(err) });
            try util.writeAll(io, .stderr(), msg);
            continue;
        };
        defer arena.free(resolved);
        try w.writeAll(resolved);
        try w.writeAll("\n");
    }
    try w.flush();
}

fn resolvePath(io: Io, arena: mem.Allocator, path: []const u8) ![]u8 {
    const cwd = try process.currentPathAlloc(io, arena);
    defer arena.free(cwd);

    const full = if (path.len > 0 and path[0] == '/')
        try arena.dupe(u8, path)
    else
        try std.fmt.allocPrint(arena, "{s}/{s}", .{ cwd, path });

    // Split and resolve . and .. (dupe components so we can free full)
    var parts: std.ArrayListUnmanaged([]const u8) = .empty;
    defer {
        for (parts.items) |part| arena.free(part);
        parts.deinit(arena);
    }

    var it = mem.tokenizeScalar(u8, full, '/');
    while (it.next()) |part| {
        if (part.len == 0 or mem.eql(u8, part, ".")) continue;
        if (mem.eql(u8, part, "..")) {
            if (parts.items.len > 0) {
                const dropped = parts.pop().?;
                arena.free(dropped);
            }
            continue;
        }
        try parts.append(arena, try arena.dupe(u8, part));
    }
    arena.free(full);

    var out: std.ArrayListUnmanaged(u8) = .empty;
    errdefer out.deinit(arena);
    try out.append(arena, '/');
    for (parts.items, 0..) |part, idx| {
        if (idx > 0) try out.append(arena, '/');
        try out.appendSlice(arena, part);
    }
    return try out.toOwnedSlice(arena);
}
