const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdInstall(io: Io, args: []const [:0]const u8) !void {
    // install [-m MODE] [-d] SRC... DEST  or  install -d DIR...
    var mode: u32 = 0o755;
    var dirs_only = false;
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        const a = args[i];
        if (mem.eql(u8, a, "-d") or mem.eql(u8, a, "--directory")) {
            dirs_only = true;
        } else if (mem.eql(u8, a, "-m") and i + 1 < args.len) {
            i += 1;
            mode = std.fmt.parseInt(u32, args[i], 8) catch 0o755;
        } else if (a.len > 2 and a[0] == '-' and a[1] == 'm') {
            mode = std.fmt.parseInt(u32, a[2..], 8) catch 0o755;
        }
    }
    if (i >= args.len) {
        try util.writeAll(io, .stderr(), "install: missing operand\n");
        std.process.exit(1);
    }

    const perms = Io.File.Permissions.fromMode(@intCast(mode));

    if (dirs_only) {
        while (i < args.len) : (i += 1) {
            Io.Dir.cwd().createDirPath(io, args[i]) catch {};
            Io.Dir.cwd().setFilePermissions(io, args[i], perms, .{}) catch {};
        }
        return;
    }

    if (i + 1 >= args.len) {
        try util.writeAll(io, .stderr(), "install: missing destination\n");
        std.process.exit(1);
    }
    const dest = args[args.len - 1];
    const sources = args[i .. args.len - 1];

    // If multiple sources, dest must be directory
    const dest_is_dir = blk: {
        const st = Io.Dir.cwd().statFile(io, dest, .{}) catch break :blk false;
        break :blk st.kind == .directory;
    };

    if (sources.len > 1 and !dest_is_dir) {
        try util.writeAll(io, .stderr(), "install: target is not a directory\n");
        std.process.exit(1);
    }

    for (sources) |src| {
        var dest_buf: [Io.Dir.max_path_bytes]u8 = undefined;
        const target = if (dest_is_dir or sources.len > 1)
            try std.fmt.bufPrint(&dest_buf, "{s}/{s}", .{ dest, util.basename(src) })
        else
            dest;

        {
            const src_f = Io.Dir.cwd().openFile(io, src, .{}) catch |err| {
                var buf: [256]u8 = undefined;
                const msg = try std.fmt.bufPrint(&buf, "install: {s}: {s}\n", .{ src, @errorName(err) });
                try util.writeAll(io, .stderr(), msg);
                continue;
            };
            defer src_f.close(io);
            const dst_f = Io.Dir.cwd().createFile(io, target, .{}) catch |err| {
                var buf: [256]u8 = undefined;
                const msg = try std.fmt.bufPrint(&buf, "install: {s}: {s}\n", .{ target, @errorName(err) });
                try util.writeAll(io, .stderr(), msg);
                continue;
            };
            defer dst_f.close(io);
            util.copyFile(io, src_f, dst_f) catch |err| {
                var buf: [256]u8 = undefined;
                const msg = try std.fmt.bufPrint(&buf, "install: {s}: {s}\n", .{ target, @errorName(err) });
                try util.writeAll(io, .stderr(), msg);
                continue;
            };
        }
        Io.Dir.cwd().setFilePermissions(io, target, perms, .{}) catch |err| {
            var buf: [256]u8 = undefined;
            const msg = try std.fmt.bufPrint(&buf, "install: {s}: {s}\n", .{ target, @errorName(err) });
            try util.writeAll(io, .stderr(), msg);
        };
    }
}
