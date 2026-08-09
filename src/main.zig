const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const posix = std.posix;
const builtin = @import("builtin");

pub fn main(init: process.Init) !void {
    const arena = init.arena.allocator();
    const io = init.io;
    const args = try init.minimal.args.toSlice(arena);
    const environ = init.environ_map;

    if (args.len == 0) {
        try printUsage(io);
        return;
    }

    // Determine applet name: basename of argv[0], or if multi-call name then argv[1]
    const applet = getAppletName(args);

    // Shift args if called as cube <cmd>
    const cmd_args = if (isMultiCallName(args[0]))
        if (args.len > 1) args[1..] else args[0..0]
    else
        args;

    try dispatch(io, arena, applet, cmd_args, environ);
}

fn isMultiCallName(name: []const u8) bool {
    const base = basename(name);
    return mem.eql(u8, base, "cube")
        or mem.eql(u8, base, "busybox")
        or mem.eql(u8, base, "bb");
}

fn getAppletName(args: []const [:0]const u8) []const u8 {
    if (args.len == 0) return "cube";
    const base = basename(args[0]);
    if (isMultiCallName(args[0])) {
        if (args.len > 1) return args[1];
        return "cube";
    }
    return base;
}

fn basename(path: []const u8) []const u8 {
    if (mem.lastIndexOfScalar(u8, path, '/')) |idx| {
        return path[idx + 1 ..];
    }
    return path;
}

fn dispatch(
    io: Io,
    arena: mem.Allocator,
    applet: []const u8,
    args: []const [:0]const u8,
    environ: *process.Environ.Map,
) !void {
    // args[0] is the applet name when called via cube
    const argv = if (args.len > 0 and mem.eql(u8, args[0], applet))
        args
    else blk: {
        // Reconstruct with applet as args[0]
        var list = try arena.alloc([:0]const u8, args.len + 1);
        list[0] = try arena.dupeZ(u8, applet);
        @memcpy(list[1..], args);
        break :blk list;
    };

    if (mem.eql(u8, applet, "cube") or mem.eql(u8, applet, "busybox") or mem.eql(u8, applet, "--help") or mem.eql(u8, applet, "help")) {
        try printUsage(io);
    } else if (mem.eql(u8, applet, "echo")) {
        try cmdEcho(io, argv);
    } else if (mem.eql(u8, applet, "true")) {
        // exit 0
    } else if (mem.eql(u8, applet, "false")) {
        std.process.exit(1);
    } else if (mem.eql(u8, applet, "cat")) {
        try cmdCat(io, argv);
    } else if (mem.eql(u8, applet, "ls")) {
        try cmdLs(io, arena, argv);
    } else if (mem.eql(u8, applet, "pwd")) {
        try cmdPwd(io, arena);
    } else if (mem.eql(u8, applet, "mkdir")) {
        try cmdMkdir(io, argv);
    } else if (mem.eql(u8, applet, "rmdir")) {
        try cmdRmdir(io, argv);
    } else if (mem.eql(u8, applet, "rm")) {
        try cmdRm(io, arena, argv);
    } else if (mem.eql(u8, applet, "touch")) {
        try cmdTouch(io, argv);
    } else if (mem.eql(u8, applet, "cp")) {
        try cmdCp(io, arena, argv);
    } else if (mem.eql(u8, applet, "mv")) {
        try cmdMv(io, argv);
    } else if (mem.eql(u8, applet, "ln")) {
        try cmdLn(io, argv);
    } else if (mem.eql(u8, applet, "sleep")) {
        try cmdSleep(io, argv);
    } else if (mem.eql(u8, applet, "yes")) {
        try cmdYes(io, argv);
    } else if (mem.eql(u8, applet, "head")) {
        try cmdHead(io, argv);
    } else if (mem.eql(u8, applet, "tail")) {
        try cmdTail(io, arena, argv);
    } else if (mem.eql(u8, applet, "wc")) {
        try cmdWc(io, argv);
    } else if (mem.eql(u8, applet, "basename")) {
        try cmdBasename(io, argv);
    } else if (mem.eql(u8, applet, "dirname")) {
        try cmdDirname(io, argv);
    } else if (mem.eql(u8, applet, "uname")) {
        try cmdUname(io, argv);
    } else if (mem.eql(u8, applet, "whoami")) {
        try cmdWhoami(io);
    } else if (mem.eql(u8, applet, "id")) {
        try cmdId(io);
    } else if (mem.eql(u8, applet, "date")) {
        try cmdDate(io);
    } else if (mem.eql(u8, applet, "clear")) {
        try cmdClear(io);
    } else if (mem.eql(u8, applet, "seq")) {
        try cmdSeq(io, argv);
    } else if (mem.eql(u8, applet, "test") or mem.eql(u8, applet, "[")) {
        try cmdTest(argv);
    } else if (mem.eql(u8, applet, "printf")) {
        try cmdPrintf(io, argv);
    } else if (mem.eql(u8, applet, "env") or mem.eql(u8, applet, "printenv")) {
        try cmdEnv(io, argv, environ);
    } else {
        var buf: [256]u8 = undefined;
        const msg = try std.fmt.bufPrint(&buf, "cube: {s}: applet not found\n", .{applet});
        try writeAll(io, .stderr(), msg);
        std.process.exit(127);
    }
}

fn printUsage(io: Io) !void {
    const usage =
        \\cube - multi-call binary (BusyBox-style) v0.2
        \\Usage: cube <applet> [args]  or  <applet> [args] (via symlink)
        \\
        \\Available applets:
        \\  echo true false cat ls pwd mkdir rmdir rm touch cp mv ln
        \\  sleep yes head tail wc basename dirname uname whoami id
        \\  date clear seq test [ printf env printenv
        \\
        \\See ROADMAP.md and docs/ for status and planned features.
        \\
    ;
    try writeAll(io, .stdout(), usage);
}

fn writeAll(io: Io, file: Io.File, data: []const u8) !void {
    var buf: [4096]u8 = undefined;
    var writer: Io.File.Writer = .init(file, io, &buf);
    try writer.interface.writeAll(data);
    try writer.interface.flush();
}

fn writeAllNoFlush(io: Io, file: Io.File, data: []const u8) !void {
    var buf: [4096]u8 = undefined;
    var writer: Io.File.Writer = .init(file, io, &buf);
    try writer.interface.writeAll(data);
}

// --- Applets ---

fn cmdEcho(io: Io, args: []const [:0]const u8) !void {
    var buf: [4096]u8 = undefined;
    var writer: Io.File.Writer = .init(.stdout(), io, &buf);
    const w = &writer.interface;

    var n_flag = false;
    var start: usize = 1;
    if (args.len > 1 and mem.eql(u8, args[1], "-n")) {
        n_flag = true;
        start = 2;
    }

    var first = true;
    for (args[start..]) |arg| {
        if (!first) try w.writeAll(" ");
        try w.writeAll(arg);
        first = false;
    }
    if (!n_flag) try w.writeAll("\n");
    try w.flush();
}

fn cmdCat(io: Io, args: []const [:0]const u8) !void {
    if (args.len <= 1) {
        // read stdin
        try copyFile(io, .stdin(), .stdout());
        return;
    }
    for (args[1..]) |path| {
        const file = Io.Dir.cwd().openFile(io, path, .{}) catch |err| {
            var buf: [512]u8 = undefined;
            const msg = try std.fmt.bufPrint(&buf, "cat: {s}: {s}\n", .{ path, @errorName(err) });
            try writeAll(io, .stderr(), msg);
            continue;
        };
        defer file.close(io);
        try copyFile(io, file, .stdout());
    }
}

fn copyFile(io: Io, src: Io.File, dst: Io.File) !void {
    var rbuf: [8192]u8 = undefined;
    var reader: Io.File.Reader = .init(src, io, &rbuf);
    var wbuf: [8192]u8 = undefined;
    var writer: Io.File.Writer = .init(dst, io, &wbuf);
    while (true) {
        const n = reader.interface.readSliceShort(&rbuf) catch |err| return err;
        if (n == 0) break;
        try writer.interface.writeAll(rbuf[0..n]);
    }
    try writer.interface.flush();
}

fn cmdLs(io: Io, arena: mem.Allocator, args: []const [:0]const u8) !void {
    var opts: LsOptions = .{};
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        const a = args[i];
        if (mem.eql(u8, a, "--")) {
            i += 1;
            break;
        }
        if (mem.eql(u8, a, "--help")) {
            try writeAll(io, .stdout(),
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
    var writer: Io.File.Writer = .init(.stdout(), io, &wbuf);
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
        try writeAll(io, .stderr(), msg);
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

fn cmdPwd(io: Io, arena: mem.Allocator) !void {
    const cwd = try process.currentPathAlloc(io, arena);
    defer arena.free(cwd);
    try writeAll(io, .stdout(), cwd);
    try writeAll(io, .stdout(), "\n");
}

fn cmdMkdir(io: Io, args: []const [:0]const u8) !void {
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
        try writeAll(io, .stderr(), "mkdir: missing operand\n");
        std.process.exit(1);
    }
    for (args[i..]) |path| {
        if (parents) {
            Io.Dir.cwd().createDirPath(io, path) catch |err| {
                var buf: [512]u8 = undefined;
                const msg = try std.fmt.bufPrint(&buf, "mkdir: {s}: {s}\n", .{ path, @errorName(err) });
                try writeAll(io, .stderr(), msg);
            };
        } else {
            Io.Dir.cwd().createDir(io, path, .default_dir) catch |err| {
                var buf: [512]u8 = undefined;
                const msg = try std.fmt.bufPrint(&buf, "mkdir: {s}: {s}\n", .{ path, @errorName(err) });
                try writeAll(io, .stderr(), msg);
            };
        }
    }
}

fn cmdRmdir(io: Io, args: []const [:0]const u8) !void {
    if (args.len < 2) {
        try writeAll(io, .stderr(), "rmdir: missing operand\n");
        std.process.exit(1);
    }
    for (args[1..]) |path| {
        Io.Dir.cwd().deleteDir(io, path) catch |err| {
            var buf: [512]u8 = undefined;
            const msg = try std.fmt.bufPrint(&buf, "rmdir: {s}: {s}\n", .{ path, @errorName(err) });
            try writeAll(io, .stderr(), msg);
        };
    }
}

fn cmdRm(io: Io, arena: mem.Allocator, args: []const [:0]const u8) !void {
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
            try writeAll(io, .stderr(), "rm: missing operand\n");
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
                    try writeAll(io, .stderr(), msg);
                }
            };
        } else {
            Io.Dir.cwd().deleteFile(io, path) catch |err| {
                if (!force) {
                    var buf: [512]u8 = undefined;
                    const msg = try std.fmt.bufPrint(&buf, "rm: {s}: {s}\n", .{ path, @errorName(err) });
                    try writeAll(io, .stderr(), msg);
                }
            };
        }
    }
}

fn cmdTouch(io: Io, args: []const [:0]const u8) !void {
    if (args.len < 2) {
        try writeAll(io, .stderr(), "touch: missing file operand\n");
        std.process.exit(1);
    }
    for (args[1..]) |path| {
        const file = Io.Dir.cwd().createFile(io, path, .{}) catch {
            // try open to update mtime - simplified: just create or ignore
            const f = Io.Dir.cwd().openFile(io, path, .{ .mode = .read_write }) catch continue;
            f.close(io);
            continue;
        };
        file.close(io);
    }
}

fn cmdCp(io: Io, arena: mem.Allocator, args: []const [:0]const u8) !void {
    _ = arena;
    if (args.len < 3) {
        try writeAll(io, .stderr(), "cp: missing file operand\n");
        std.process.exit(1);
    }
    const src_path = args[args.len - 2];
    const dst_path = args[args.len - 1];
    // ignore options for now
    const src = Io.Dir.cwd().openFile(io, src_path, .{}) catch |err| {
        var buf: [512]u8 = undefined;
        const msg = try std.fmt.bufPrint(&buf, "cp: {s}: {s}\n", .{ src_path, @errorName(err) });
        try writeAll(io, .stderr(), msg);
        return;
    };
    defer src.close(io);
    const dst = Io.Dir.cwd().createFile(io, dst_path, .{}) catch |err| {
        var buf: [512]u8 = undefined;
        const msg = try std.fmt.bufPrint(&buf, "cp: {s}: {s}\n", .{ dst_path, @errorName(err) });
        try writeAll(io, .stderr(), msg);
        return;
    };
    defer dst.close(io);
    try copyFile(io, src, dst);
}

fn cmdMv(io: Io, args: []const [:0]const u8) !void {
    if (args.len < 3) {
        try writeAll(io, .stderr(), "mv: missing file operand\n");
        std.process.exit(1);
    }
    const src = args[args.len - 2];
    const dst = args[args.len - 1];
    const cwd = Io.Dir.cwd();
    cwd.rename(src, cwd, dst, io) catch |err| {
        var buf: [512]u8 = undefined;
        const msg = try std.fmt.bufPrint(&buf, "mv: {s}: {s}\n", .{ src, @errorName(err) });
        try writeAll(io, .stderr(), msg);
        std.process.exit(1);
    };
}

fn cmdLn(io: Io, args: []const [:0]const u8) !void {
    if (args.len < 3) {
        try writeAll(io, .stderr(), "ln: missing file operand\n");
        std.process.exit(1);
    }
    var symbolic = false;
    var i: usize = 1;
    while (i < args.len and args[i][0] == '-') : (i += 1) {
        if (mem.eql(u8, args[i], "-s")) symbolic = true;
    }
    if (i + 1 >= args.len) {
        try writeAll(io, .stderr(), "ln: missing file operand\n");
        std.process.exit(1);
    }
    const target = args[i];
    const linkpath = args[i + 1];
    const cwd = Io.Dir.cwd();
    if (symbolic) {
        cwd.symLink(io, target, linkpath, .{}) catch |err| {
            var buf: [512]u8 = undefined;
            const msg = try std.fmt.bufPrint(&buf, "ln: {s}\n", .{@errorName(err)});
            try writeAll(io, .stderr(), msg);
        };
    } else {
        cwd.hardLink(target, cwd, linkpath, io, .{}) catch |err| {
            var buf: [512]u8 = undefined;
            const msg = try std.fmt.bufPrint(&buf, "ln: {s}\n", .{@errorName(err)});
            try writeAll(io, .stderr(), msg);
        };
    }
}

fn cmdSleep(io: Io, args: []const [:0]const u8) !void {
    if (args.len < 2) {
        try writeAll(io, .stderr(), "sleep: missing operand\n");
        std.process.exit(1);
    }
    const secs = std.fmt.parseFloat(f64, args[1]) catch {
        try writeAll(io, .stderr(), "sleep: invalid time\n");
        std.process.exit(1);
    };
    const ns: i96 = @intFromFloat(secs * 1_000_000_000.0);
    try Io.sleep(io, .{ .nanoseconds = ns }, .real);

}

fn cmdYes(io: Io, args: []const [:0]const u8) !void {
    const str = if (args.len > 1) args[1] else "y";
    var buf: [4096]u8 = undefined;
    var writer: Io.File.Writer = .init(.stdout(), io, &buf);
    const w = &writer.interface;
    while (true) {
        try w.writeAll(str);
        try w.writeAll("\n");
        try w.flush();
    }
}

fn cmdHead(io: Io, args: []const [:0]const u8) !void {
    var lines: usize = 10;
    var file_arg: ?[:0]const u8 = null;
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (mem.eql(u8, args[i], "-n") and i + 1 < args.len) {
            lines = std.fmt.parseInt(usize, args[i + 1], 10) catch 10;
            i += 1;
        } else if (args[i][0] != '-') {
            file_arg = args[i];
        }
    }
    const file = if (file_arg) |p|
        Io.Dir.cwd().openFile(io, p, .{}) catch |err| {
            var b: [256]u8 = undefined;
            const msg = try std.fmt.bufPrint(&b, "head: {s}\n", .{@errorName(err)});
            try writeAll(io, .stderr(), msg);
            return;
        }
    else
        Io.File.stdin();
    defer if (file_arg != null) file.close(io);

    var rbuf: [4096]u8 = undefined;
    var reader: Io.File.Reader = .init(file, io, &rbuf);
    var wbuf: [4096]u8 = undefined;
    var writer: Io.File.Writer = .init(.stdout(), io, &wbuf);
    var count: usize = 0;
    while (count < lines) {
        const line = (reader.interface.takeDelimiter('\n') catch |err| return err) orelse break;
        try writer.interface.writeAll(line);
        try writer.interface.writeAll("\n");
        count += 1;
    }
    try writer.interface.flush();
}

fn cmdTail(io: Io, arena: mem.Allocator, args: []const [:0]const u8) !void {
    // Simplified: just print last 10 lines by buffering
    var lines: usize = 10;
    var file_arg: ?[:0]const u8 = null;
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (mem.eql(u8, args[i], "-n") and i + 1 < args.len) {
            lines = std.fmt.parseInt(usize, args[i + 1], 10) catch 10;
            i += 1;
        } else if (args[i][0] != '-') {
            file_arg = args[i];
        }
    }
    const file = if (file_arg) |p|
        Io.Dir.cwd().openFile(io, p, .{}) catch |err| {
            var b: [256]u8 = undefined;
            const msg = try std.fmt.bufPrint(&b, "tail: {s}\n", .{@errorName(err)});
            try writeAll(io, .stderr(), msg);
            return;
        }
    else
        Io.File.stdin();
    defer if (file_arg != null) file.close(io);

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
        if (list.items.len > lines) {
            arena.free(list.orderedRemove(0));
        }
    }

    var wbuf: [4096]u8 = undefined;
    var writer: Io.File.Writer = .init(.stdout(), io, &wbuf);
    for (list.items) |l| {
        try writer.interface.writeAll(l);
        try writer.interface.writeAll("\n");
    }
    try writer.interface.flush();
}

fn cmdWc(io: Io, args: []const [:0]const u8) !void {
    // Simple line/word/byte count for files or stdin
    var lines: usize = 0;
    var words: usize = 0;
    var bytes: usize = 0;

    const countStream = struct {
        fn f(io_: Io, file: Io.File, l: *usize, w: *usize, b: *usize) !void {
            var rbuf: [8192]u8 = undefined;
            var reader: Io.File.Reader = .init(file, io_, &rbuf);
            var in_word = false;
            while (true) {
                const n = reader.interface.readSliceShort(&rbuf) catch |err| return err;
                if (n == 0) break;
                b.* += n;
                for (rbuf[0..n]) |c| {
                    if (c == '\n') l.* += 1;
                    if (c == ' ' or c == '\t' or c == '\n') {
                        in_word = false;
                    } else if (!in_word) {
                        in_word = true;
                        w.* += 1;
                    }
                }
            }
        }
    }.f;

    if (args.len <= 1) {
        try countStream(io, .stdin(), &lines, &words, &bytes);
        var buf: [128]u8 = undefined;
        const msg = try std.fmt.bufPrint(&buf, "{d} {d} {d}\n", .{ lines, words, bytes });
        try writeAll(io, .stdout(), msg);
    } else {
        for (args[1..]) |path| {
            lines = 0;
            words = 0;
            bytes = 0;
            const file = Io.Dir.cwd().openFile(io, path, .{}) catch continue;
            defer file.close(io);
            try countStream(io, file, &lines, &words, &bytes);
            var buf: [256]u8 = undefined;
            const msg = try std.fmt.bufPrint(&buf, "{d} {d} {d} {s}\n", .{ lines, words, bytes, path });
            try writeAll(io, .stdout(), msg);
        }
    }
}

fn cmdBasename(io: Io, args: []const [:0]const u8) !void {
    if (args.len < 2) {
        try writeAll(io, .stderr(), "basename: missing operand\n");
        std.process.exit(1);
    }
    const base = basename(args[1]);
    try writeAll(io, .stdout(), base);
    try writeAll(io, .stdout(), "\n");
}

fn cmdDirname(io: Io, args: []const [:0]const u8) !void {
    if (args.len < 2) {
        try writeAll(io, .stderr(), "dirname: missing operand\n");
        std.process.exit(1);
    }
    const p = args[1];
    if (mem.lastIndexOfScalar(u8, p, '/')) |idx| {
        if (idx == 0) {
            try writeAll(io, .stdout(), "/\n");
        } else {
            try writeAll(io, .stdout(), p[0..idx]);
            try writeAll(io, .stdout(), "\n");
        }
    } else {
        try writeAll(io, .stdout(), ".\n");
    }
}

fn cmdUname(io: Io, args: []const [:0]const u8) !void {
    _ = args;
    // Simple: print system info
    const info = builtin.os.tag;
    const arch = @tagName(builtin.cpu.arch);
    var buf: [128]u8 = undefined;
    const msg = try std.fmt.bufPrint(&buf, "Linux {s} unknown unknown {s} GNU/Linux\n", .{ arch, arch });
    try writeAll(io, .stdout(), msg);
    _ = info;
}

fn cmdWhoami(io: Io) !void {
    // Simplified
    try writeAll(io, .stdout(), "user\n");
}

fn cmdId(io: Io) !void {
    try writeAll(io, .stdout(), "uid=1000(user) gid=1000(user) groups=1000(user)\n");
}

fn cmdDate(io: Io) !void {
    const ts = Io.Timestamp.now(io, .real);
    const secs = @divTrunc(ts.nanoseconds, 1_000_000_000);
    var buf: [64]u8 = undefined;
    const msg = try std.fmt.bufPrint(&buf, "{d}\n", .{secs});
    try writeAll(io, .stdout(), msg);
}

fn cmdClear(io: Io) !void {
    try writeAll(io, .stdout(), "\x1b[2J\x1b[H");
}

fn cmdSeq(io: Io, args: []const [:0]const u8) !void {
    if (args.len < 2) {
        try writeAll(io, .stderr(), "seq: missing operand\n");
        std.process.exit(1);
    }
    var start: i64 = 1;
    var step: i64 = 1;
    var end: i64 = undefined;
    if (args.len == 2) {
        end = std.fmt.parseInt(i64, args[1], 10) catch {
            try writeAll(io, .stderr(), "seq: invalid\n");
            std.process.exit(1);
        };
    } else if (args.len == 3) {
        start = std.fmt.parseInt(i64, args[1], 10) catch 1;
        end = std.fmt.parseInt(i64, args[2], 10) catch {
            try writeAll(io, .stderr(), "seq: invalid\n");
            std.process.exit(1);
        };
    } else {
        start = std.fmt.parseInt(i64, args[1], 10) catch 1;
        step = std.fmt.parseInt(i64, args[2], 10) catch 1;
        end = std.fmt.parseInt(i64, args[3], 10) catch {
            try writeAll(io, .stderr(), "seq: invalid\n");
            std.process.exit(1);
        };
    }
    var buf: [4096]u8 = undefined;
    var writer: Io.File.Writer = .init(.stdout(), io, &buf);
    const w = &writer.interface;
    var i = start;
    while ((step > 0 and i <= end) or (step < 0 and i >= end)) : (i += step) {
        try w.print("{d}\n", .{i});
    }
    try w.flush();
}

fn cmdTest(args: []const [:0]const u8) !void {
    // Very minimal [ ] support: just exit 0/1 based on simple checks
    // e.g. [ -f file ], [ -d dir ], [ str1 = str2 ]
    if (args.len < 2) {
        std.process.exit(1);
    }
    // If last is ], ignore it
    const end = if (mem.eql(u8, args[args.len - 1], "]")) args.len - 1 else args.len;
    if (end < 2) {
        std.process.exit(1);
    }
    // For simplicity, always true for now or implement basic
    // TODO: better test
    if (end >= 3 and mem.eql(u8, args[1], "-f")) {
        // check file exists - skip real check for now
        std.process.exit(0);
    }
    std.process.exit(0);
}

fn cmdPrintf(io: Io, args: []const [:0]const u8) !void {
    if (args.len < 2) {
        // printf with no format → exit 0 (POSIX)
        return;
    }
    const fmt = args[1];
    var arg_i: usize = 2;

    var buf: [8192]u8 = undefined;
    var writer: Io.File.Writer = .init(.stdout(), io, &buf);
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

fn cmdEnv(io: Io, args: []const [:0]const u8, environ: *process.Environ.Map) !void {
    // printenv NAME  or  env   or  env KEY=VAL ...
    var buf: [4096]u8 = undefined;
    var writer: Io.File.Writer = .init(.stdout(), io, &buf);
    const w = &writer.interface;

    if (args.len >= 2 and !mem.eql(u8, args[0], "env")) {
        // printenv VAR
        const key = args[1];
        if (environ.get(key)) |val| {
            try w.writeAll(val);
            try w.writeAll("\n");
        } else {
            std.process.exit(1);
        }
        try w.flush();
        return;
    }

    // env with no args → print all
    // simple: iterate map if API allows
    var it = environ.iterator();
    while (it.next()) |entry| {
        try w.writeAll(entry.key_ptr.*);
        try w.writeAll("=");
        try w.writeAll(entry.value_ptr.*);
        try w.writeAll("\n");
    }
    try w.flush();
}
