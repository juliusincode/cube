const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdChmod(io: Io, arena: mem.Allocator, args: []const [:0]const u8) !void {
    // chmod [-R] MODE FILE...  (numeric mode only, e.g. 755 or 0755)
    var recursive = false;
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        for (args[i][1..]) |c| {
            if (c == 'R' or c == 'r') recursive = true;
        }
    }
    if (i >= args.len) {
        try util.writeAll(io, .stderr(), "chmod: missing operand\n");
        std.process.exit(1);
    }
    const mode_str = args[i];
    i += 1;
    if (i >= args.len) {
        try util.writeAll(io, .stderr(), "chmod: missing file operand\n");
        std.process.exit(1);
    }

    const mode_val = std.fmt.parseInt(u32, mode_str, 8) catch {
        try util.writeAll(io, .stderr(), "chmod: invalid mode (use octal, e.g. 755)\n");
        std.process.exit(1);
    };
    const perms = Io.File.Permissions.fromMode(@intCast(mode_val));

    var failed = false;
    while (i < args.len) : (i += 1) {
        if (recursive) {
            chmodRecursive(io, arena, args[i], perms, &failed) catch |err| {
                var buf: [256]u8 = undefined;
                const msg = try std.fmt.bufPrint(&buf, "chmod: {s}: {s}\n", .{ args[i], @errorName(err) });
                try util.writeAll(io, .stderr(), msg);
                failed = true;
            };
        } else {
            Io.Dir.cwd().setFilePermissions(io, args[i], perms, .{}) catch |err| {
                var buf: [256]u8 = undefined;
                const msg = try std.fmt.bufPrint(&buf, "chmod: {s}: {s}\n", .{ args[i], @errorName(err) });
                try util.writeAll(io, .stderr(), msg);
                failed = true;
            };
        }
    }
    if (failed) std.process.exit(1);
}

fn chmodRecursive(io: Io, arena: mem.Allocator, path: []const u8, perms: Io.File.Permissions, failed: *bool) !void {
    Io.Dir.cwd().setFilePermissions(io, path, perms, .{}) catch |err| {
        var buf: [256]u8 = undefined;
        const msg = try std.fmt.bufPrint(&buf, "chmod: {s}: {s}\n", .{ path, @errorName(err) });
        try util.writeAll(io, .stderr(), msg);
        failed.* = true;
    };

    const st = Io.Dir.cwd().statFile(io, path, .{ .follow_symlinks = false }) catch return;
    if (st.kind != .directory) return;

    var dir = Io.Dir.cwd().openDir(io, path, .{ .iterate = true }) catch return;
    defer dir.close(io);
    var it = dir.iterate();
    while (try it.next(io)) |entry| {
        if (mem.eql(u8, entry.name, ".") or mem.eql(u8, entry.name, "..")) continue;
        const child = try std.fmt.allocPrint(arena, "{s}/{s}", .{ path, entry.name });
        defer arena.free(child);
        try chmodRecursive(io, arena, child, perms, failed);
    }
}
