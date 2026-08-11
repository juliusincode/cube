const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdLs(io: Io, arena: mem.Allocator, args: []const [:0]const u8) !void {
    var opts: LsOptions = .{};
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        const a = args[i];
        if (mem.eql(u8, a, "--")) {
            i += 1;
            break;
        }
        if (mem.eql(u8, a, "--help")) {
            try util.writeAll(io, .stdout(),
                \\Usage: ls [-aAlhdF] [FILE]...
                \\  -a  all (including . and ..)
                \\  -A  almost all (exclude . and ..)
                \\  -l  long listing
                \\  -h  human-readable sizes (with -l)
                \\  -d  list directories themselves
                \\  -F  append indicator (*/=@|) to entries
                \\
            );
            return;
        }
        // cluster: -la, -lh, …
        for (a[1..]) |c| {
            switch (c) {
                'a' => opts.all = true,
                'A' => opts.almost_all = true,
                'l' => opts.long = true,
                'h' => opts.human = true,
                'd' => opts.directory = true,
                'F' => opts.classify = true,
                '1' => {}, // one per line – already default
                else => {},
            }
        }
    }

    const paths: []const [:0]const u8 = if (i >= args.len)
        &[_][:0]const u8{"."}
    else
        args[i..];

    var wbuf: [8192]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const w = &writer.interface;

    // Headers only when listing multiple directories (not with -d)
    const multi = paths.len > 1 and !opts.directory;
    for (paths, 0..) |path, pi| {
        if (multi) {
            if (pi > 0) try w.writeAll("\n");
            try w.print("{s}:\n", .{path});
        }
        try lsOne(io, arena, w, path, opts);
    }
    try w.flush();
}

const LsOptions = struct {
    all: bool = false,
    almost_all: bool = false,
    long: bool = false,
    human: bool = false,
    directory: bool = false,
    classify: bool = false,
};

fn lsOne(io: Io, arena: mem.Allocator, w: anytype, path: []const u8, opts: LsOptions) !void {
    if (opts.directory) {
        try printLsEntry(io, w, Io.Dir.cwd(), path, path, opts);
        return;
    }

    var dir = Io.Dir.cwd().openDir(io, path, .{ .iterate = true }) catch {
        // Not a directory – treat as single file entry
        try printLsEntry(io, w, Io.Dir.cwd(), path, path, opts);
        return;
    };
    defer dir.close(io);

    const EntryInfo = struct {
        name: [:0]const u8,
        kind: Io.File.Kind,
    };

    var entries: std.ArrayListUnmanaged(EntryInfo) = .empty;
    defer {
        for (entries.items) |e| arena.free(e.name);
        entries.deinit(arena);
    }

    var it = dir.iterate();
    while (try it.next(io)) |entry| {
        const name = entry.name;
        if (name.len > 0 and name[0] == '.') {
            if (opts.all) {
                // keep
            } else if (opts.almost_all) {
                if (mem.eql(u8, name, ".") or mem.eql(u8, name, "..")) continue;
            } else {
                continue;
            }
        }
        const owned = try arena.dupeZ(u8, name);
        try entries.append(arena, .{ .name = owned, .kind = entry.kind });
    }

    std.mem.sort(EntryInfo, entries.items, {}, struct {
        fn less(_: void, a: EntryInfo, b: EntryInfo) bool {
            return mem.order(u8, a.name, b.name) == .lt;
        }
    }.less);

    for (entries.items) |e| {
        try printLsEntry(io, w, dir, e.name, e.name, opts);
    }
}

fn printLsEntry(
    io: Io,
    w: anytype,
    dir: Io.Dir,
    name_for_stat: []const u8,
    display_name: []const u8,
    opts: LsOptions,
) !void {
    if (!opts.long) {
        try w.writeAll(display_name);
        if (opts.classify) {
            if (dir.statFile(io, name_for_stat, .{})) |s| {
                try w.writeAll(classifySuffix(s.kind));
            } else |_| {}
        }
        try w.writeAll("\n");
        return;
    }

    const st = dir.statFile(io, name_for_stat, .{}) catch |err| {
        var ebuf: [256]u8 = undefined;
        const msg = try std.fmt.bufPrint(&ebuf, "ls: {s}: {s}\n", .{ display_name, @errorName(err) });
        try util.writeAll(io, .stderr(), msg);
        return;
    };

    var mode_buf: [10]u8 = undefined;
    formatMode(&mode_buf, st.kind, st.permissions);
    try w.writeAll(&mode_buf);
    try w.print(" {d:>3} ", .{st.nlink});

    if (opts.human) {
        var hb: [16]u8 = undefined;
        const hs = formatHumanSize(&hb, st.size);
        try w.print("{s:>5} ", .{hs});
    } else {
        try w.print("{d:>8} ", .{st.size});
    }

    var time_buf: [32]u8 = undefined;
    const ts = formatMtime(&time_buf, st.mtime);
    try w.print("{s} ", .{ts});

    try w.writeAll(display_name);
    if (opts.classify) {
        try w.writeAll(classifySuffix(st.kind));
    }
    try w.writeAll("\n");
}

fn classifySuffix(kind: Io.File.Kind) []const u8 {
    return switch (kind) {
        .directory => "/",
        .sym_link => "@",
        .named_pipe => "|",
        .unix_domain_socket => "=",
        else => "",
    };
}

fn formatMode(buf: *[10]u8, kind: Io.File.Kind, perms: Io.File.Permissions) void {
    buf[0] = switch (kind) {
        .directory => 'd',
        .sym_link => 'l',
        .named_pipe => 'p',
        .unix_domain_socket => 's',
        .block_device => 'b',
        .character_device => 'c',
        else => '-',
    };
    const mode: u32 = @intCast(perms.toMode());
    buf[1] = if (mode & 0o400 != 0) 'r' else '-';
    buf[2] = if (mode & 0o200 != 0) 'w' else '-';
    buf[3] = if (mode & 0o100 != 0) 'x' else '-';
    buf[4] = if (mode & 0o040 != 0) 'r' else '-';
    buf[5] = if (mode & 0o020 != 0) 'w' else '-';
    buf[6] = if (mode & 0o010 != 0) 'x' else '-';
    buf[7] = if (mode & 0o004 != 0) 'r' else '-';
    buf[8] = if (mode & 0o002 != 0) 'w' else '-';
    buf[9] = if (mode & 0o001 != 0) 'x' else '-';
}

fn formatHumanSize(buf: []u8, size: u64) []const u8 {
    const units = [_][]const u8{ "B", "K", "M", "G", "T" };
    var s: f64 = @floatFromInt(size);
    var u: usize = 0;
    while (s >= 1024.0 and u + 1 < units.len) : (u += 1) {
        s /= 1024.0;
    }
    if (u == 0) {
        return std.fmt.bufPrint(buf, "{d}{s}", .{ size, units[u] }) catch "?";
    }
    if (s >= 10.0) {
        return std.fmt.bufPrint(buf, "{d:.0}{s}", .{ s, units[u] }) catch "?";
    }
    return std.fmt.bufPrint(buf, "{d:.1}{s}", .{ s, units[u] }) catch "?";
}

fn formatMtime(buf: []u8, ts: Io.Timestamp) []const u8 {
    const secs: i64 = @intCast(@divTrunc(ts.nanoseconds, 1_000_000_000));
    if (secs < 0) return "????-??-?? ??:??";

    const SECS_PER_DAY: i64 = 86400;
    const days = @divTrunc(secs, SECS_PER_DAY);
    const sod = @mod(secs, SECS_PER_DAY);
    const hour: u32 = @intCast(@divTrunc(sod, 3600));
    const minute: u32 = @intCast(@divTrunc(@mod(sod, 3600), 60));

    // Civil from days (Howard Hinnant)
    const z = days + 719468;
    const era = if (z >= 0) @divTrunc(z, 146097) else @divTrunc(z - 146096, 146097);
    const doe = z - era * 146097;
    const yoe = @divTrunc(doe - @divTrunc(doe, 1460) + @divTrunc(doe, 36524) - @divTrunc(doe, 146096), 365);
    var y = yoe + era * 400;
    const doy = doe - (365 * yoe + @divTrunc(yoe, 4) - @divTrunc(yoe, 100));
    const mp = @divTrunc(5 * doy + 2, 153);
    const d: u32 = @intCast(doy - @divTrunc(153 * mp + 2, 5) + 1);
    const m: u32 = @intCast(if (mp < 10) mp + 3 else mp - 9);
    if (m <= 2) y += 1;

    const yu: u32 = @intCast(y);
    return std.fmt.bufPrint(buf, "{d:0>4}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}", .{ yu, m, d, hour, minute }) catch "????-??-?? ??:??";
}

pub fn cmdPwd(io: Io, arena: mem.Allocator) !void {
    const cwd = try process.currentPathAlloc(io, arena);
    defer arena.free(cwd);
    try util.writeAll(io, .stdout(), cwd);
    try util.writeAll(io, .stdout(), "\n");
}

pub fn cmdMkdir(io: Io, args: []const [:0]const u8) !void {
    var parents = false;
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        if (mem.eql(u8, args[i], "-p") or mem.eql(u8, args[i], "--parents")) {
            parents = true;
        } else if (mem.eql(u8, args[i], "--")) {
            i += 1;
            break;
        } else {
            // ignore unknown for now
        }
    }
    if (i >= args.len) {
        try util.writeAll(io, .stderr(), "mkdir: missing operand\n");
        std.process.exit(1);
    }
    for (args[i..]) |path| {
        if (parents) {
            Io.Dir.cwd().createDirPath(io, path) catch |err| {
                var buf: [512]u8 = undefined;
                const msg = try std.fmt.bufPrint(&buf, "mkdir: {s}: {s}\n", .{ path, @errorName(err) });
                try util.writeAll(io, .stderr(), msg);
            };
        } else {
            Io.Dir.cwd().createDir(io, path, .default_dir) catch |err| {
                var buf: [512]u8 = undefined;
                const msg = try std.fmt.bufPrint(&buf, "mkdir: {s}: {s}\n", .{ path, @errorName(err) });
                try util.writeAll(io, .stderr(), msg);
            };
        }
    }
}

pub fn cmdRmdir(io: Io, args: []const [:0]const u8) !void {
    if (args.len < 2) {
        try util.writeAll(io, .stderr(), "rmdir: missing operand\n");
        std.process.exit(1);
    }
    for (args[1..]) |path| {
        Io.Dir.cwd().deleteDir(io, path) catch |err| {
            var buf: [512]u8 = undefined;
            const msg = try std.fmt.bufPrint(&buf, "rmdir: {s}: {s}\n", .{ path, @errorName(err) });
            try util.writeAll(io, .stderr(), msg);
        };
    }
}

pub fn cmdRm(io: Io, arena: mem.Allocator, args: []const [:0]const u8) !void {
    _ = arena;
    var recursive = false;
    var force = false;
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        const opt = args[i];
        if (mem.eql(u8, opt, "--")) {
            i += 1;
            break;
        }
        if (mem.eql(u8, opt, "-r") or mem.eql(u8, opt, "-R") or mem.eql(u8, opt, "--recursive")) {
            recursive = true;
        } else if (mem.eql(u8, opt, "-f") or mem.eql(u8, opt, "--force")) {
            force = true;
        } else if (mem.eql(u8, opt, "-rf") or mem.eql(u8, opt, "-fr") or mem.eql(u8, opt, "-Rf") or mem.eql(u8, opt, "-fR")) {
            recursive = true;
            force = true;
        } else {
            // single-letter cluster e.g. -rf already handled; ignore others
        }
    }
    if (i >= args.len) {
        if (!force) {
            try util.writeAll(io, .stderr(), "rm: missing operand\n");
            std.process.exit(1);
        }
        return;
    }
    for (args[i..]) |path| {
        if (recursive) {
            Io.Dir.cwd().deleteTree(io, path) catch |err| {
                if (!force) {
                    var buf: [512]u8 = undefined;
                    const msg = try std.fmt.bufPrint(&buf, "rm: {s}: {s}\n", .{ path, @errorName(err) });
                    try util.writeAll(io, .stderr(), msg);
                }
            };
        } else {
            Io.Dir.cwd().deleteFile(io, path) catch |err| {
                if (!force) {
                    var buf: [512]u8 = undefined;
                    const msg = try std.fmt.bufPrint(&buf, "rm: {s}: {s}\n", .{ path, @errorName(err) });
                    try util.writeAll(io, .stderr(), msg);
                }
            };
        }
    }
}

pub fn cmdTouch(io: Io, args: []const [:0]const u8) !void {
    var no_create = false; // -c
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        const a = args[i];
        if (mem.eql(u8, a, "--")) {
            i += 1;
            break;
        }
        for (a[1..]) |c| {
            switch (c) {
                'c' => no_create = true,
                else => {},
            }
        }
    }
    if (i >= args.len) {
        try util.writeAll(io, .stderr(), "touch: missing file operand\n");
        std.process.exit(1);
    }
    for (args[i..]) |path| {
        const file = Io.Dir.cwd().openFile(io, path, .{ .mode = .read_write }) catch {
            if (no_create) continue;
            const created = Io.Dir.cwd().createFile(io, path, .{}) catch |err| {
                var buf: [512]u8 = undefined;
                const msg = try std.fmt.bufPrint(&buf, "touch: {s}: {s}\n", .{ path, @errorName(err) });
                try util.writeAll(io, .stderr(), msg);
                continue;
            };
            created.close(io);
            continue;
        };
        defer file.close(io);
        file.setTimestampsNow(io) catch {};
    }
}

pub fn cmdCp(io: Io, arena: mem.Allocator, args: []const [:0]const u8) !void {
    var recursive = false;
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        const opt = args[i];
        if (mem.eql(u8, opt, "--")) {
            i += 1;
            break;
        }
        if (mem.eql(u8, opt, "-r") or mem.eql(u8, opt, "-R") or mem.eql(u8, opt, "--recursive")) {
            recursive = true;
        } else if (mem.eql(u8, opt, "-rf") or mem.eql(u8, opt, "-fr") or mem.eql(u8, opt, "-Rf") or mem.eql(u8, opt, "-fR")) {
            recursive = true;
        }
        // other flags ignored for now
    }
    if (i + 1 >= args.len) {
        try util.writeAll(io, .stderr(), "cp: missing file operand\n");
        std.process.exit(1);
    }
    // Support: cp [-r] SRC... DEST  — for now require exactly one SRC and DEST
    // when more than two operands and dest is dir, copy each into dest (basic)
    const operands = args[i..];
    if (operands.len < 2) {
        try util.writeAll(io, .stderr(), "cp: missing file operand\n");
        std.process.exit(1);
    }
    const dest = operands[operands.len - 1];
    const sources = operands[0 .. operands.len - 1];

    // Check if dest is an existing directory
    const dest_is_dir = blk: {
        const st = Io.Dir.cwd().statFile(io, dest, .{}) catch break :blk false;
        break :blk st.kind == .directory;
    };

    if (sources.len > 1 and !dest_is_dir) {
        try util.writeAll(io, .stderr(), "cp: target is not a directory\n");
        std.process.exit(1);
    }

    for (sources) |src_path| {
        var dest_path_buf: [Io.Dir.max_path_bytes]u8 = undefined;
        const dest_path: []const u8 = if (dest_is_dir) blk: {
            const base = util.basename(src_path);
            break :blk try std.fmt.bufPrint(&dest_path_buf, "{s}/{s}", .{ dest, base });
        } else dest;

        try copyPath(io, arena, src_path, dest_path, recursive);
    }
}

fn copyPath(io: Io, arena: mem.Allocator, src_path: []const u8, dest_path: []const u8, recursive: bool) anyerror!void {
    const st = Io.Dir.cwd().statFile(io, src_path, .{}) catch |err| {
        var buf: [512]u8 = undefined;
        const msg = try std.fmt.bufPrint(&buf, "cp: {s}: {s}\n", .{ src_path, @errorName(err) });
        try util.writeAll(io, .stderr(), msg);
        return;
    };

    if (st.kind == .directory) {
        if (!recursive) {
            var buf: [512]u8 = undefined;
            const msg = try std.fmt.bufPrint(&buf, "cp: -r not specified; omitting directory '{s}'\n", .{src_path});
            try util.writeAll(io, .stderr(), msg);
            return;
        }
        try copyDirRecursive(io, arena, src_path, dest_path);
        return;
    }

    // regular file (or other)
    const src = Io.Dir.cwd().openFile(io, src_path, .{}) catch |err| {
        var buf: [512]u8 = undefined;
        const msg = try std.fmt.bufPrint(&buf, "cp: {s}: {s}\n", .{ src_path, @errorName(err) });
        try util.writeAll(io, .stderr(), msg);
        return;
    };
    defer src.close(io);
    const dst = Io.Dir.cwd().createFile(io, dest_path, .{}) catch |err| {
        var buf: [512]u8 = undefined;
        const msg = try std.fmt.bufPrint(&buf, "cp: {s}: {s}\n", .{ dest_path, @errorName(err) });
        try util.writeAll(io, .stderr(), msg);
        return;
    };
    defer dst.close(io);
    try util.copyFile(io, src, dst);
}

fn copyDirRecursive(io: Io, arena: mem.Allocator, src_path: []const u8, dest_path: []const u8) anyerror!void {
    Io.Dir.cwd().createDir(io, dest_path, .default_dir) catch |err| {
        // ok if exists
        if (err != error.PathAlreadyExists) {
            var buf: [512]u8 = undefined;
            const msg = try std.fmt.bufPrint(&buf, "cp: {s}: {s}\n", .{ dest_path, @errorName(err) });
            try util.writeAll(io, .stderr(), msg);
            return;
        }
    };

    var dir = Io.Dir.cwd().openDir(io, src_path, .{ .iterate = true }) catch |err| {
        var buf: [512]u8 = undefined;
        const msg = try std.fmt.bufPrint(&buf, "cp: {s}: {s}\n", .{ src_path, @errorName(err) });
        try util.writeAll(io, .stderr(), msg);
        return;
    };
    defer dir.close(io);

    var it = dir.iterate();
    while (try it.next(io)) |entry| {
        if (mem.eql(u8, entry.name, ".") or mem.eql(u8, entry.name, "..")) continue;
        const child_src = try std.fmt.allocPrint(arena, "{s}/{s}", .{ src_path, entry.name });
        defer arena.free(child_src);
        const child_dst = try std.fmt.allocPrint(arena, "{s}/{s}", .{ dest_path, entry.name });
        defer arena.free(child_dst);
        try copyPath(io, arena, child_src, child_dst, true);
    }
}

pub fn cmdMv(io: Io, args: []const [:0]const u8) !void {
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        if (mem.eql(u8, args[i], "--")) {
            i += 1;
            break;
        }
        // -v/-f ignored for now
    }
    if (i + 1 >= args.len) {
        try util.writeAll(io, .stderr(), "mv: missing file operand\n");
        std.process.exit(1);
    }
    const operands = args[i..];
    const dest = operands[operands.len - 1];
    const sources = operands[0 .. operands.len - 1];

    const dest_is_dir = blk: {
        const st = Io.Dir.cwd().statFile(io, dest, .{}) catch break :blk false;
        break :blk st.kind == .directory;
    };

    if (sources.len > 1 and !dest_is_dir) {
        try util.writeAll(io, .stderr(), "mv: target is not a directory\n");
        std.process.exit(1);
    }

    const cwd = Io.Dir.cwd();
    for (sources) |src| {
        var dest_buf: [Io.Dir.max_path_bytes]u8 = undefined;
        const dest_path: []const u8 = if (dest_is_dir) blk: {
            const base = util.basename(src);
            break :blk try std.fmt.bufPrint(&dest_buf, "{s}/{s}", .{ dest, base });
        } else dest;

        cwd.rename(src, cwd, dest_path, io) catch |err| {
            var buf: [512]u8 = undefined;
            const msg = try std.fmt.bufPrint(&buf, "mv: {s}: {s}\n", .{ src, @errorName(err) });
            try util.writeAll(io, .stderr(), msg);
            std.process.exit(1);
        };
    }
}

pub fn cmdLn(io: Io, args: []const [:0]const u8) !void {
    var symbolic = false;
    var force = false;
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        const a = args[i];
        if (mem.eql(u8, a, "--")) {
            i += 1;
            break;
        }
        for (a[1..]) |c| {
            switch (c) {
                's' => symbolic = true,
                'f' => force = true,
                else => {},
            }
        }
    }
    if (i + 1 >= args.len) {
        try util.writeAll(io, .stderr(), "ln: missing file operand\n");
        std.process.exit(1);
    }
    const target = args[i];
    const linkpath = args[i + 1];
    const cwd = Io.Dir.cwd();

    if (force) {
        cwd.deleteFile(io, linkpath) catch {};
    }

    if (symbolic) {
        cwd.symLink(io, target, linkpath, .{}) catch |err| {
            var buf: [512]u8 = undefined;
            const msg = try std.fmt.bufPrint(&buf, "ln: {s}\n", .{@errorName(err)});
            try util.writeAll(io, .stderr(), msg);
            std.process.exit(1);
        };
    } else {
        cwd.hardLink(target, cwd, linkpath, io, .{}) catch |err| {
            var buf: [512]u8 = undefined;
            const msg = try std.fmt.bufPrint(&buf, "ln: {s}\n", .{@errorName(err)});
            try util.writeAll(io, .stderr(), msg);
            std.process.exit(1);
        };
    }
}

pub fn cmdBasename(io: Io, args: []const [:0]const u8) !void {
    if (args.len < 2) {
        try util.writeAll(io, .stderr(), "basename: missing operand\n");
        std.process.exit(1);
    }
    const base = util.basename(args[1]);
    try util.writeAll(io, .stdout(), base);
    try util.writeAll(io, .stdout(), "\n");
}

pub fn cmdDirname(io: Io, args: []const [:0]const u8) !void {
    if (args.len < 2) {
        try util.writeAll(io, .stderr(), "dirname: missing operand\n");
        std.process.exit(1);
    }
    const p = args[1];
    if (mem.lastIndexOfScalar(u8, p, '/')) |idx| {
        if (idx == 0) {
            try util.writeAll(io, .stdout(), "/\n");
        } else {
            try util.writeAll(io, .stdout(), p[0..idx]);
            try util.writeAll(io, .stdout(), "\n");
        }
    } else {
        try util.writeAll(io, .stdout(), ".\n");
    }
}


pub fn cmdReadlink(io: Io, args: []const [:0]const u8) !void {
    var i: usize = 1;
    var no_newline = false;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        for (args[i][1..]) |c| {
            if (c == 'n') no_newline = true;
        }
    }
    if (i >= args.len) {
        try util.writeAll(io, .stderr(), "readlink: missing operand\n");
        std.process.exit(1);
    }
    const path = args[i];
    var buf: [Io.Dir.max_path_bytes]u8 = undefined;
    const n = Io.Dir.cwd().readLink(io, path, &buf) catch |err| {
        var ebuf: [256]u8 = undefined;
        const msg = try std.fmt.bufPrint(&ebuf, "readlink: {s}: {s}\n", .{ path, @errorName(err) });
        try util.writeAll(io, .stderr(), msg);
        std.process.exit(1);
    };
    try util.writeAll(io, .stdout(), buf[0..n]);
    if (!no_newline) try util.writeAll(io, .stdout(), "\n");
}


pub fn cmdFind(io: Io, arena: mem.Allocator, args: []const [:0]const u8) !void {
    // find [PATH...] [EXPRESSION]
    // Supported: -name PATTERN, -type f|d|l, -maxdepth N
    // Default path: .
    var paths: std.ArrayListUnmanaged([]const u8) = .empty;
    defer paths.deinit(arena);

    var name_pat: ?[]const u8 = null;
    var type_filter: ?u8 = null; // 'f', 'd', 'l'
    var maxdepth: ?usize = null;

    var i: usize = 1;
    // Collect leading paths (not starting with -)
    while (i < args.len and args[i].len > 0 and args[i][0] != '-') : (i += 1) {
        try paths.append(arena, args[i]);
    }
    // Parse expression
    while (i < args.len) : (i += 1) {
        const a = args[i];
        if (mem.eql(u8, a, "-name") and i + 1 < args.len) {
            i += 1;
            name_pat = args[i];
        } else if (mem.eql(u8, a, "-type") and i + 1 < args.len) {
            i += 1;
            if (args[i].len > 0) type_filter = args[i][0];
        } else if (mem.eql(u8, a, "-maxdepth") and i + 1 < args.len) {
            i += 1;
            maxdepth = std.fmt.parseInt(usize, args[i], 10) catch null;
        } else if (a[0] != '-') {
            // extra path mid-expression: treat as path
            try paths.append(arena, a);
        }
    }

    if (paths.items.len == 0) {
        try paths.append(arena, ".");
    }

    var wbuf: [8192]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const w = &writer.interface;

    const opts = FindOpts{
        .name_pat = name_pat,
        .type_filter = type_filter,
        .maxdepth = maxdepth,
    };

    for (paths.items) |root| {
        try findWalk(io, arena, w, root, 0, opts);
    }
    try w.flush();
}

const FindOpts = struct {
    name_pat: ?[]const u8,
    type_filter: ?u8,
    maxdepth: ?usize,
};

fn findWalk(
    io: Io,
    arena: mem.Allocator,
    w: anytype,
    path: []const u8,
    depth: usize,
    opts: FindOpts,
) anyerror!void {
    // Do not follow symlinks so -type l works
    const st = Io.Dir.cwd().statFile(io, path, .{ .follow_symlinks = false }) catch |err| {
        var buf: [512]u8 = undefined;
        const msg = try std.fmt.bufPrint(&buf, "find: {s}: {s}\n", .{ path, @errorName(err) });
        try util.writeAll(io, .stderr(), msg);
        return;
    };

    if (findMatch(util.basename(path), st.kind, opts)) {
        try w.writeAll(path);
        try w.writeAll("\n");
    }

    // Do not descend into symlinked directories
    if (st.kind != .directory) return;
    if (opts.maxdepth) |md| {
        if (depth >= md) return;
    }

    var dir = Io.Dir.cwd().openDir(io, path, .{ .iterate = true }) catch |err| {
        var buf: [512]u8 = undefined;
        const msg = try std.fmt.bufPrint(&buf, "find: {s}: {s}\n", .{ path, @errorName(err) });
        try util.writeAll(io, .stderr(), msg);
        return;
    };
    defer dir.close(io);

    var it = dir.iterate();
    while (try it.next(io)) |entry| {
        if (mem.eql(u8, entry.name, ".") or mem.eql(u8, entry.name, "..")) continue;
        const child = if (path.len == 0 or mem.eql(u8, path, "."))
            try std.fmt.allocPrint(arena, "./{s}", .{entry.name})
        else if (path[path.len - 1] == '/')
            try std.fmt.allocPrint(arena, "{s}{s}", .{ path, entry.name })
        else
            try std.fmt.allocPrint(arena, "{s}/{s}", .{ path, entry.name });
        defer arena.free(child);
        try findWalk(io, arena, w, child, depth + 1, opts);
    }
}


fn findMatch(name: []const u8, kind: Io.File.Kind, opts: FindOpts) bool {
    if (opts.type_filter) |tf| {
        const ok = switch (tf) {
            'f' => kind == .file,
            'd' => kind == .directory,
            'l' => kind == .sym_link,
            'b' => kind == .block_device,
            'c' => kind == .character_device,
            'p' => kind == .named_pipe,
            's' => kind == .unix_domain_socket,
            else => true,
        };
        if (!ok) return false;
    }
    if (opts.name_pat) |pat| {
        if (!globMatch(pat, name)) return false;
    }
    return true;
}

/// Simple glob: * (any sequence), ? (single char). No ** or character classes.
fn globMatch(pattern: []const u8, text: []const u8) bool {
    return globMatchInner(pattern, text);
}

fn globMatchInner(pattern: []const u8, text: []const u8) bool {
    var pi: usize = 0;
    var ti: usize = 0;
    var star_p: ?usize = null;
    var star_t: usize = 0;

    while (ti < text.len) {
        if (pi < pattern.len and (pattern[pi] == text[ti] or pattern[pi] == '?')) {
            pi += 1;
            ti += 1;
        } else if (pi < pattern.len and pattern[pi] == '*') {
            star_p = pi;
            star_t = ti;
            pi += 1;
        } else if (star_p) |sp| {
            pi = sp + 1;
            star_t += 1;
            ti = star_t;
        } else {
            return false;
        }
    }
    while (pi < pattern.len and pattern[pi] == '*') : (pi += 1) {}
    return pi == pattern.len;
}


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
        const s = formatHumanSize(&buf, size);
        try w.writeAll(s);
    } else {
        // 512-byte blocks like traditional du, or 1024? BusyBox often uses 512 or -k.
        // Use 1024-byte blocks for simplicity.
        try w.print("{d}", .{(size + 1023) / 1024});
    }
}

pub fn cmdDf(io: Io, args: []const [:0]const u8) !void {
    var human = false;
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        for (args[i][1..]) |c| {
            if (c == 'h') human = true;
        }
    }

    var wbuf: [2048]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const w = &writer.interface;

    if (human) {
        try w.writeAll("Filesystem     Size  Used Avail Use% Mounted on\n");
    } else {
        try w.writeAll("Filesystem     1K-blocks    Used Available Use% Mounted on\n");
    }

    // Parse /proc/mounts
    const mounts = Io.Dir.cwd().openFile(io, "/proc/mounts", .{}) catch {
        // Fallback: just df on given paths or /
        const paths: []const [:0]const u8 = if (i >= args.len) &[_][:0]const u8{"/"} else args[i..];
        for (paths) |path| {
            try dfOne(io, w, path, path, human);
        }
        try w.flush();
        return;
    };
    defer mounts.close(io);

    var rbuf: [4096]u8 = undefined;
    var reader: Io.File.Reader = .init(mounts, io, &rbuf);
    const filter_paths = if (i < args.len) args[i..] else null;

    while (true) {
        const line = (reader.interface.takeDelimiter('\n') catch break) orelse break;
        // format: device mountpoint fstype options ...
        var it = mem.tokenizeScalar(u8, line, ' ');
        const device = it.next() orelse continue;
        const mountpoint = it.next() orelse continue;
        const fstype = it.next() orelse continue;
        _ = fstype;

        // Skip virtual fs types commonly noisy
        if (mem.eql(u8, device, "none") or mem.eql(u8, device, "tmpfs") and false) {}
        if (mem.startsWith(u8, device, "/dev/") or mem.eql(u8, device, "tmpfs") or mem.eql(u8, device, "overlay")) {
            // ok
        } else if (mem.indexOfScalar(u8, device, '/') == null) {
            continue; // skip proc, sysfs, etc.
        }

        if (filter_paths) |fps| {
            var ok = false;
            for (fps) |fp| {
                if (mem.eql(u8, fp, mountpoint) or mem.eql(u8, fp, device)) ok = true;
            }
            if (!ok) continue;
        }

        try dfOne(io, w, device, mountpoint, human);
    }
    try w.flush();
}

fn dfOne(io: Io, w: anytype, device: []const u8, mountpoint: []const u8, human: bool) !void {
    const linux = std.os.linux;
    // Linux struct for statfs on x86_64
    const Statfs = extern struct {
        f_type: i64,
        f_bsize: i64,
        f_blocks: u64,
        f_bfree: u64,
        f_bavail: u64,
        f_files: u64,
        f_ffree: u64,
        f_fsid: [2]i32,
        f_namelen: i64,
        f_frsize: i64,
        f_flags: i64,
        f_spare: [4]i64,
    };
    var st: Statfs = undefined;
    var path_buf: [Io.Dir.max_path_bytes]u8 = undefined;
    if (mountpoint.len >= path_buf.len) return;
    @memcpy(path_buf[0..mountpoint.len], mountpoint);
    path_buf[mountpoint.len] = 0;
    const rc = linux.syscall2(.statfs, @intFromPtr(&path_buf), @intFromPtr(&st));
    if (@as(isize, @bitCast(rc)) < 0) return;

    const bsize: u64 = if (st.f_frsize > 0) @intCast(st.f_frsize) else if (st.f_bsize > 0) @intCast(st.f_bsize) else 1024;
    const total_b = st.f_blocks * bsize;
    const avail_b = st.f_bavail * bsize;
    const free_b = st.f_bfree * bsize;
    const used_b = if (total_b > free_b) total_b - free_b else 0;
    const pct: u64 = if (total_b == 0) 0 else (used_b * 100) / total_b;

    const dev_show = if (device.len > 14) device[0..14] else device;
    try w.print("{s:<14} ", .{dev_show});

    if (human) {
        var b1: [16]u8 = undefined;
        var b2: [16]u8 = undefined;
        var b3: [16]u8 = undefined;
        try w.print("{s:>5} {s:>5} {s:>5} {d:>3}% {s}\n", .{
            formatHumanSize(&b1, total_b),
            formatHumanSize(&b2, used_b),
            formatHumanSize(&b3, avail_b),
            pct,
            mountpoint,
        });
    } else {
        try w.print("{d:>10} {d:>8} {d:>9} {d:>3}% {s}\n", .{
            total_b / 1024,
            used_b / 1024,
            avail_b / 1024,
            pct,
            mountpoint,
        });
    }
    _ = io;
}


pub fn cmdMktemp(io: Io, args: []const [:0]const u8) !void {
    // mktemp [-d] [TEMPLATE]
    // TEMPLATE must contain at least 6 trailing X's (or we append them).
    var make_dir = false;
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        for (args[i][1..]) |c| {
            if (c == 'd') make_dir = true;
        }
    }
    const template: []const u8 = if (i < args.len) args[i] else "/tmp/tmp.XXXXXX";

    var buf: [Io.Dir.max_path_bytes]u8 = undefined;
    if (template.len >= buf.len) {
        try util.writeAll(io, .stderr(), "mktemp: template too long\n");
        std.process.exit(1);
    }
    @memcpy(buf[0..template.len], template);
    var path = buf[0..template.len];

    // Ensure at least 6 X at end
    var xcount: usize = 0;
    while (xcount < path.len and path[path.len - 1 - xcount] == 'X') : (xcount += 1) {}
    if (xcount < 6) {
        try util.writeAll(io, .stderr(), "mktemp: template must end in XXXXXX\n");
        std.process.exit(1);
    }

    const alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    var attempt: usize = 0;
    while (attempt < 100) : (attempt += 1) {
        // fill X's with pseudo-random from timestamp + attempt
        const ts = Io.Timestamp.now(io, .real);
        var seed: u64 = @intCast(ts.nanoseconds);
        seed ^= @as(u64, @intCast(attempt)) *% 0x9E3779B97F4A7C15;
        var k: usize = 0;
        while (k < xcount) : (k += 1) {
            seed = seed *% 6364136223846793005 +% 1;
            path[path.len - xcount + k] = alphabet[@intCast(seed % alphabet.len)];
        }

        if (make_dir) {
            Io.Dir.cwd().createDir(io, path, .default_dir) catch continue;
        } else {
            const f = Io.Dir.cwd().createFile(io, path, .{ .exclusive = true }) catch continue;
            f.close(io);
        }
        try util.writeAll(io, .stdout(), path);
        try util.writeAll(io, .stdout(), "\n");
        return;
    }
    try util.writeAll(io, .stderr(), "mktemp: failed to create file\n");
    std.process.exit(1);
}


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


pub fn cmdChmod(io: Io, args: []const [:0]const u8) !void {
    // chmod MODE FILE...  (numeric mode only, e.g. 755 or 0755)
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        // ignore flags for now (-R later)
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
        Io.Dir.cwd().setFilePermissions(io, args[i], perms, .{}) catch |err| {
            var buf: [256]u8 = undefined;
            const msg = try std.fmt.bufPrint(&buf, "chmod: {s}: {s}\n", .{ args[i], @errorName(err) });
            try util.writeAll(io, .stderr(), msg);
            failed = true;
        };
    }
    if (failed) std.process.exit(1);
}


pub fn cmdTruncate(io: Io, args: []const [:0]const u8) !void {
    // truncate -s SIZE FILE...
    // SIZE: N, Nk, Nm, Ng (bytes); optional leading + or - not supported for simplicity
    var size: ?u64 = null;
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        const a = args[i];
        if ((mem.eql(u8, a, "-s") or mem.eql(u8, a, "--size")) and i + 1 < args.len) {
            i += 1;
            size = parseSize(args[i]) catch {
                try util.writeAll(io, .stderr(), "truncate: invalid size\n");
                std.process.exit(1);
            };
        } else if (a.len > 2 and a[0] == '-' and a[1] == 's') {
            size = parseSize(a[2..]) catch {
                try util.writeAll(io, .stderr(), "truncate: invalid size\n");
                std.process.exit(1);
            };
        }
    }
    if (size == null) {
        try util.writeAll(io, .stderr(), "truncate: must specify -s SIZE\n");
        std.process.exit(1);
    }
    if (i >= args.len) {
        try util.writeAll(io, .stderr(), "truncate: missing file operand\n");
        std.process.exit(1);
    }

    const sz = size.?;
    var failed = false;
    while (i < args.len) : (i += 1) {
        const path = args[i];
        // create if missing, don't truncate content on open
        const file = Io.Dir.cwd().createFile(io, path, .{ .truncate = false }) catch |err| {
            var buf: [256]u8 = undefined;
            const msg = try std.fmt.bufPrint(&buf, "truncate: {s}: {s}\n", .{ path, @errorName(err) });
            try util.writeAll(io, .stderr(), msg);
            failed = true;
            continue;
        };
        defer file.close(io);
        file.setLength(io, sz) catch |err| {
            var buf: [256]u8 = undefined;
            const msg = try std.fmt.bufPrint(&buf, "truncate: {s}: {s}\n", .{ path, @errorName(err) });
            try util.writeAll(io, .stderr(), msg);
            failed = true;
        };
    }
    if (failed) std.process.exit(1);
}

fn parseSize(s: []const u8) !u64 {
    if (s.len == 0) return error.InvalidSize;
    var end = s.len;
    var mul: u64 = 1;
    const last = s[s.len - 1];
    if (last == 'k' or last == 'K') {
        mul = 1024;
        end = s.len - 1;
    } else if (last == 'm' or last == 'M') {
        mul = 1024 * 1024;
        end = s.len - 1;
    } else if (last == 'g' or last == 'G') {
        mul = 1024 * 1024 * 1024;
        end = s.len - 1;
    } else if (last == 'c' or last == 'b') {
        end = s.len - 1;
    }
    const n = try std.fmt.parseInt(u64, s[0..end], 10);
    return n *% mul;
}


pub fn cmdUnlink(io: Io, args: []const [:0]const u8) !void {
    // unlink FILE  — remove a single file (not directory)
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {}
    if (i >= args.len) {
        try util.writeAll(io, .stderr(), "unlink: missing operand\n");
        std.process.exit(1);
    }
    // POSIX unlink takes exactly one file; allow multiple like busybox sometimes does
    var failed = false;
    while (i < args.len) : (i += 1) {
        Io.Dir.cwd().deleteFile(io, args[i]) catch |err| {
            var buf: [256]u8 = undefined;
            const msg = try std.fmt.bufPrint(&buf, "unlink: {s}: {s}\n", .{ args[i], @errorName(err) });
            try util.writeAll(io, .stderr(), msg);
            failed = true;
        };
    }
    if (failed) std.process.exit(1);
}


test "classifySuffix" {
    try std.testing.expectEqualStrings("/", classifySuffix(.directory));
    try std.testing.expectEqualStrings("@", classifySuffix(.sym_link));
    try std.testing.expectEqualStrings("|", classifySuffix(.named_pipe));
    try std.testing.expectEqualStrings("=", classifySuffix(.unix_domain_socket));
    try std.testing.expectEqualStrings("", classifySuffix(.file));
}

test "formatMode regular file 644" {
    var buf: [10]u8 = undefined;
    formatMode(&buf, .file, .fromMode(0o644));
    try std.testing.expectEqualStrings("-rw-r--r--", &buf);
}

test "formatMode directory 755" {
    var buf: [10]u8 = undefined;
    formatMode(&buf, .directory, .fromMode(0o755));
    try std.testing.expectEqualStrings("drwxr-xr-x", &buf);
}

test "formatMode symlink" {
    var buf: [10]u8 = undefined;
    formatMode(&buf, .sym_link, .fromMode(0o777));
    try std.testing.expectEqualStrings("lrwxrwxrwx", &buf);
}

test "formatHumanSize" {
    var buf: [32]u8 = undefined;
    try std.testing.expectEqualStrings("0B", formatHumanSize(&buf, 0));
    try std.testing.expectEqualStrings("512B", formatHumanSize(&buf, 512));
    try std.testing.expectEqualStrings("1.0K", formatHumanSize(&buf, 1024));
    try std.testing.expectEqualStrings("1.5K", formatHumanSize(&buf, 1536));
    try std.testing.expectEqualStrings("1.0M", formatHumanSize(&buf, 1024 * 1024));
}

test "globMatch exact" {
    try std.testing.expect(globMatch("file.txt", "file.txt"));
    try std.testing.expect(!globMatch("file.txt", "file.tx"));
}

test "globMatch star" {
    try std.testing.expect(globMatch("*.txt", "file.txt"));
    try std.testing.expect(globMatch("file.*", "file.txt"));
    try std.testing.expect(globMatch("*", "anything"));
    try std.testing.expect(!globMatch("*.txt", "file.log"));
    try std.testing.expect(globMatch("pre*suf", "preXXXsuf"));
}

test "globMatch question" {
    try std.testing.expect(globMatch("a?c", "abc"));
    try std.testing.expect(!globMatch("a?c", "ac"));
    try std.testing.expect(globMatch("??", "ab"));
}
