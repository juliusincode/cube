const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");
const common = @import("common.zig");

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
            common.formatHumanSize(&b1, total_b),
            common.formatHumanSize(&b2, used_b),
            common.formatHumanSize(&b3, avail_b),
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
