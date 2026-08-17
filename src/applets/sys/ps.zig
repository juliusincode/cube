const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const posix = std.posix;
const util = @import("util");

pub fn cmdPs(io: Io, arena: mem.Allocator, args: []const [:0]const u8) !void {
    // BusyBox-style ps from /proc
    // Columns: PID USER VSZ RSS STAT COMMAND
    // Flags: -p PID (filter), -A/-e (all, default)
    var filter_pid: ?i32 = null;
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const a = args[i];
        if (mem.eql(u8, a, "-p") and i + 1 < args.len) {
            i += 1;
            filter_pid = std.fmt.parseInt(i32, args[i], 10) catch null;
        } else if (a.len > 2 and a[0] == '-' and a[1] == 'p') {
            filter_pid = std.fmt.parseInt(i32, a[2..], 10) catch null;
        }
        // -A -e -a accepted, no-op (always all)
    }
    _ = arena;

    var wbuf: [8192]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const w = &writer.interface;

    try w.writeAll("  PID USER         VSZ    RSS STAT COMMAND\n");

    var proc_dir = Io.Dir.cwd().openDir(io, "/proc", .{ .iterate = true }) catch |err| {
        var buf: [128]u8 = undefined;
        const msg = try std.fmt.bufPrint(&buf, "ps: /proc: {s}\n", .{@errorName(err)});
        try util.writeAll(io, .stderr(), msg);
        std.process.exit(1);
    };
    defer proc_dir.close(io);

    var it = proc_dir.iterate();
    while (try it.next(io)) |entry| {
        if (entry.kind != .directory) continue;
        const pid = std.fmt.parseInt(i32, entry.name, 10) catch continue;
        if (filter_pid) |fp| {
            if (pid != fp) continue;
        }

        const info = readProcInfo(io, entry.name) orelse continue;

        // USER: show uid number (or root for 0)
        var user_buf: [16]u8 = undefined;
        const user = if (info.uid == 0)
            "root"
        else
            (std.fmt.bufPrint(&user_buf, "{d}", .{info.uid}) catch "?");

        try w.print("{d:>5} {s:<8} {d:>8} {d:>6} {c:<4} {s}\n", .{
            @as(u32, @intCast(pid)),
            user,
            info.vsz_kb,
            info.rss_kb,
            info.state,
            info.cmd,
        });
    }
    try w.flush();
}

const ProcInfo = struct {
    uid: u32,
    vsz_kb: u64,
    rss_kb: u64,
    state: u8,
    cmd: []const u8,
    cmd_storage: [256]u8 = undefined,
};

fn readProcInfo(io: Io, pid_name: []const u8) ?ProcInfo {
    var info: ProcInfo = .{
        .uid = 0,
        .vsz_kb = 0,
        .rss_kb = 0,
        .state = '?',
        .cmd = "",
    };

    // --- status: Uid, VmSize, VmRSS ---
    var status_path: [64]u8 = undefined;
    const sp = std.fmt.bufPrint(&status_path, "/proc/{s}/status", .{pid_name}) catch return null;
    if (Io.Dir.cwd().openFile(io, sp, .{})) |sf| {
        defer sf.close(io);
        var sbuf: [2048]u8 = undefined;
        var sreader: Io.File.Reader = .init(sf, io, &sbuf);
        // Read whole file in chunks into a local buffer
        var content: [2048]u8 = undefined;
        var clen: usize = 0;
        while (clen < content.len) {
            const n = sreader.interface.readSliceShort(content[clen..]) catch break;
            if (n == 0) break;
            clen += n;
        }
        var lines = mem.splitScalar(u8, content[0..clen], '\n');
        while (lines.next()) |line| {
            if (mem.startsWith(u8, line, "Uid:")) {
                // Uid:\tReal\tEffective\t...
                var it = mem.tokenizeAny(u8, line["Uid:".len..], " \t");
                if (it.next()) |u| {
                    info.uid = std.fmt.parseInt(u32, u, 10) catch 0;
                }
            } else if (mem.startsWith(u8, line, "VmSize:")) {
                var it = mem.tokenizeAny(u8, line["VmSize:".len..], " \t");
                if (it.next()) |v| {
                    info.vsz_kb = std.fmt.parseInt(u64, v, 10) catch 0;
                }
            } else if (mem.startsWith(u8, line, "VmRSS:")) {
                var it = mem.tokenizeAny(u8, line["VmRSS:".len..], " \t");
                if (it.next()) |v| {
                    info.rss_kb = std.fmt.parseInt(u64, v, 10) catch 0;
                }
            } else if (mem.startsWith(u8, line, "State:")) {
                // State:\tR (running)
                var it = mem.tokenizeAny(u8, line["State:".len..], " \t");
                if (it.next()) |st| {
                    if (st.len > 0) info.state = st[0];
                }
            }
        }
    } else |_| {
        return null;
    }

    // --- cmdline / comm ---
    if (readCmdline(io, pid_name, &info.cmd_storage)) |c| {
        info.cmd = c;
    } else {
        // fallback: /proc/pid/comm
        var cpath: [64]u8 = undefined;
        const cp = std.fmt.bufPrint(&cpath, "/proc/{s}/comm", .{pid_name}) catch return info;
        if (Io.Dir.cwd().openFile(io, cp, .{})) |cf| {
            defer cf.close(io);
            var cbuf: [64]u8 = undefined;
            var cr: Io.File.Reader = .init(cf, io, &cbuf);
            var tmp: [64]u8 = undefined;
            const n = cr.interface.readSliceShort(&tmp) catch 0;
            if (n > 0) {
                const len = if (tmp[n - 1] == '\n') n - 1 else n;
                const copy_len = @min(len, info.cmd_storage.len);
                @memcpy(info.cmd_storage[0..copy_len], tmp[0..copy_len]);
                info.cmd = info.cmd_storage[0..copy_len];
            }
        } else |_| {}
    }
    return info;
}

fn readCmdline(io: Io, pid_name: []const u8, buf: []u8) ?[]const u8 {
    var path_buf: [64]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/proc/{s}/cmdline", .{pid_name}) catch return null;
    const file = Io.Dir.cwd().openFile(io, path, .{}) catch return null;
    defer file.close(io);

    var rbuf: [256]u8 = undefined;
    var reader: Io.File.Reader = .init(file, io, &rbuf);
    var outbuf: [256]u8 = undefined;
    const n = reader.interface.readSliceShort(&outbuf) catch return null;
    if (n == 0) return null;

    const limit = @min(n, buf.len);
    var i: usize = 0;
    while (i < limit) : (i += 1) {
        buf[i] = if (outbuf[i] == 0) ' ' else outbuf[i];
    }
    var end = limit;
    while (end > 0 and buf[end - 1] == ' ') : (end -= 1) {}
    if (end == 0) return null;
    return buf[0..end];
}
