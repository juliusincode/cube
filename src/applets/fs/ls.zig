const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");
const common = @import("common.zig");

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
        const hs = common.formatHumanSize(&hb, st.size);
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

test "classifySuffix" {
    try std.testing.expectEqualStrings("/", classifySuffix(.directory));
    try std.testing.expectEqualStrings("@", classifySuffix(.sym_link));
    try std.testing.expectEqualStrings("|", classifySuffix(.named_pipe));
    try std.testing.expectEqualStrings("=", classifySuffix(.unix_domain_socket));
    try std.testing.expectEqualStrings("", classifySuffix(.file));
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
