const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const posix = std.posix;
const util = @import("util");

pub fn cmdSleep(io: Io, args: []const [:0]const u8) !void {
    if (args.len < 2) {
        try util.writeAll(io, .stderr(), "sleep: missing operand\n");
        std.process.exit(1);
    }
    const secs = std.fmt.parseFloat(f64, args[1]) catch {
        try util.writeAll(io, .stderr(), "sleep: invalid time\n");
        std.process.exit(1);
    };
    const ns: i96 = @intFromFloat(secs * 1_000_000_000.0);
    try Io.sleep(io, .{ .nanoseconds = ns }, .real);

}

pub fn cmdUname(io: Io, args: []const [:0]const u8) !void {
    var print_s = false;
    var print_n = false;
    var print_r = false;
    var print_v = false;
    var print_m = false;
    var print_all = false;
    var any = false;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const a = args[i];
        if (a.len > 0 and a[0] == '-') {
            for (a[1..]) |c| {
                switch (c) {
                    's' => {
                        print_s = true;
                        any = true;
                    },
                    'n' => {
                        print_n = true;
                        any = true;
                    },
                    'r' => {
                        print_r = true;
                        any = true;
                    },
                    'v' => {
                        print_v = true;
                        any = true;
                    },
                    'm' => {
                        print_m = true;
                        any = true;
                    },
                    'a' => {
                        print_all = true;
                        any = true;
                    },
                    else => {},
                }
            }
        }
    }
    if (!any) print_s = true;
    if (print_all) {
        print_s = true;
        print_n = true;
        print_r = true;
        print_v = true;
        print_m = true;
    }

    const uts = posix.uname();
    var wbuf: [512]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const w = &writer.interface;

    var first = true;
    const fields = [_]struct { flag: bool, val: []const u8 }{
        .{ .flag = print_s, .val = mem.sliceTo(&uts.sysname, 0) },
        .{ .flag = print_n, .val = mem.sliceTo(&uts.nodename, 0) },
        .{ .flag = print_r, .val = mem.sliceTo(&uts.release, 0) },
        .{ .flag = print_v, .val = mem.sliceTo(&uts.version, 0) },
        .{ .flag = print_m, .val = mem.sliceTo(&uts.machine, 0) },
    };
    for (fields) |f| {
        if (!f.flag) continue;
        if (!first) try w.writeAll(" ");
        try w.writeAll(f.val);
        first = false;
    }
    try w.writeAll("\n");
    try w.flush();
}

pub fn cmdWhoami(io: Io) !void {
    const uid = std.os.linux.getuid();
    var buf: [32]u8 = undefined;
    const msg = try std.fmt.bufPrint(&buf, "{d}\n", .{uid});
    try util.writeAll(io, .stdout(), msg);
}

pub fn cmdId(io: Io) !void {
    const uid = std.os.linux.getuid();
    const gid = std.os.linux.getgid();
    const euid = std.os.linux.geteuid();
    const egid = std.os.linux.getegid();
    var buf: [128]u8 = undefined;
    const msg = if (uid == euid and gid == egid)
        try std.fmt.bufPrint(&buf, "uid={d} gid={d}\n", .{ uid, gid })
    else
        try std.fmt.bufPrint(&buf, "uid={d} gid={d} euid={d} egid={d}\n", .{ uid, gid, euid, egid });
    try util.writeAll(io, .stdout(), msg);
}

pub fn cmdDate(io: Io, args: []const [:0]const u8) !void {
    const ts = Io.Timestamp.now(io, .real);
    const secs: i64 = @intCast(@divTrunc(ts.nanoseconds, 1_000_000_000));

    // Optional +FORMAT
    var fmt_str: ?[]const u8 = null;
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (args[i].len > 0 and args[i][0] == '+') {
            fmt_str = args[i][1..];
            break;
        }
    }

    var wbuf: [512]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const w = &writer.interface;

    if (fmt_str) |fmt| {
        try formatDate(w, secs, fmt);
        try w.writeAll("\n");
    } else {
        // default: human-ish local breakdown + epoch
        try formatDate(w, secs, "%Y-%m-%d %H:%M:%S");
        try w.writeAll("\n");
    }
    try w.flush();
}

fn formatDate(w: anytype, epoch_secs: i64, fmt: []const u8) !void {
    // Civil date from days (Howard Hinnant algorithm)
    const secs_per_day: i64 = 86400;
    var days = @divTrunc(epoch_secs, secs_per_day);
    var sod = @rem(epoch_secs, secs_per_day);
    if (sod < 0) {
        sod += secs_per_day;
        days -= 1;
    }
    const hour: u32 = @intCast(@divTrunc(sod, 3600));
    const minute: u32 = @intCast(@divTrunc(@rem(sod, 3600), 60));
    const second: u32 = @intCast(@rem(sod, 60));

    const z = days + 719468;
    const era = if (z >= 0) @divTrunc(z, 146097) else @divTrunc(z - 146096, 146097);
    const doe: u32 = @intCast(z - era * 146097);
    const yoe: u32 = @divTrunc(doe - @divTrunc(doe, 1460) + @divTrunc(doe, 36524) - @divTrunc(doe, 146096), 365);
    var y: i32 = @intCast(yoe + era * 400);
    const doy: u32 = doe - (365 * yoe + @divTrunc(yoe, 4) - @divTrunc(yoe, 100));
    const mp: u32 = @divTrunc(5 * doy + 2, 153);
    const d: u32 = doy - @divTrunc(153 * mp + 2, 5) + 1;
    const m: u32 = if (mp < 10) mp + 3 else mp - 9;
    if (m <= 2) y += 1;

    const months = [_][]const u8{ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };
    const days_w = [_][]const u8{ "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" };
    // 1970-01-01 was Thursday → (days + 4) mod 7
    const wday: u32 = @intCast(@mod(days + 4, 7));

    var fi: usize = 0;
    while (fi < fmt.len) {
        if (fmt[fi] == '%' and fi + 1 < fmt.len) {
            fi += 1;
            const c = fmt[fi];
            fi += 1;
            switch (c) {
                'Y' => try w.print("{d:0>4}", .{@as(u32, @intCast(y))}),
                'm' => try w.print("{d:0>2}", .{m}),
                'd' => try w.print("{d:0>2}", .{d}),
                'H' => try w.print("{d:0>2}", .{hour}),
                'M' => try w.print("{d:0>2}", .{minute}),
                'S' => try w.print("{d:0>2}", .{second}),
                's' => try w.print("{d}", .{epoch_secs}),
                'b' => try w.writeAll(months[m - 1]),
                'a' => try w.writeAll(days_w[wday]),
                '%' => try w.writeAll("%"),
                else => {
                    try w.writeAll("%");
                    try w.writeAll(&.{c});
                },
            }
        } else {
            try w.writeAll(fmt[fi .. fi + 1]);
            fi += 1;
        }
    }
}

pub fn cmdHostname(io: Io, args: []const [:0]const u8) !void {
    _ = args;
    const uts = posix.uname();
    const name = mem.sliceTo(&uts.nodename, 0);
    try util.writeAll(io, .stdout(), name);
    try util.writeAll(io, .stdout(), "\n");
}

pub fn cmdUptime(io: Io, args: []const [:0]const u8) !void {
    _ = args;
    const linux = std.os.linux;
    var info: linux.Sysinfo = undefined;
    if (linux.sysinfo(&info) != 0) {
        try util.writeAll(io, .stderr(), "uptime: sysinfo failed\n");
        std.process.exit(1);
    }
    const up: i64 = info.uptime;
    const days = @divTrunc(up, 86400);
    const hours = @divTrunc(@rem(up, 86400), 3600);
    const mins = @divTrunc(@rem(up, 3600), 60);

    var wbuf: [256]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const w = &writer.interface;
    try w.writeAll("up ");
    if (days > 0) try w.print("{d} days, ", .{@as(u64, @intCast(days))});
    try w.print("{d}:{d:0>2}", .{ @as(u64, @intCast(hours)), @as(u64, @intCast(mins)) });
    // load averages: values are scaled by 65536
    const scale: f64 = 65536.0;
    const l0: f64 = @as(f64, @floatFromInt(info.loads[0])) / scale;
    const l1: f64 = @as(f64, @floatFromInt(info.loads[1])) / scale;
    const l2: f64 = @as(f64, @floatFromInt(info.loads[2])) / scale;
    try w.print(", load average: {d:.2}, {d:.2}, {d:.2}\n", .{ l0, l1, l2 });
    try w.flush();
}

pub fn cmdFree(io: Io, args: []const [:0]const u8) !void {
    var human = false;
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        for (args[i][1..]) |c| {
            if (c == 'h') human = true;
        }
    }

    const linux = std.os.linux;
    var info: linux.Sysinfo = undefined;
    if (linux.sysinfo(&info) != 0) {
        try util.writeAll(io, .stderr(), "free: sysinfo failed\n");
        std.process.exit(1);
    }
    const unit: u64 = if (info.mem_unit == 0) 1 else info.mem_unit;
    const total = info.totalram * unit;
    const free_r = info.freeram * unit;
    const shared = info.sharedram * unit;
    const buffers = info.bufferram * unit;
    const used = if (total > free_r) total - free_r else 0;
    const swap_total = info.totalswap * unit;
    const swap_free = info.freeswap * unit;
    const swap_used = if (swap_total > swap_free) swap_total - swap_free else 0;

    var wbuf: [512]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const w = &writer.interface;

    if (human) {
        var b: [5][16]u8 = undefined;
        try w.writeAll("              total        used        free      shared     buffers\n");
        try w.print("Mem:    {s:>12} {s:>12} {s:>12} {s:>12} {s:>12}\n", .{
            formatBytes(&b[0], total),
            formatBytes(&b[1], used),
            formatBytes(&b[2], free_r),
            formatBytes(&b[3], shared),
            formatBytes(&b[4], buffers),
        });
        try w.print("Swap:   {s:>12} {s:>12} {s:>12}\n", .{
            formatBytes(&b[0], swap_total),
            formatBytes(&b[1], swap_used),
            formatBytes(&b[2], swap_free),
        });
    } else {
        try w.writeAll("              total        used        free      shared     buffers\n");
        try w.print("Mem:    {d:>12} {d:>12} {d:>12} {d:>12} {d:>12}\n", .{
            total / 1024, used / 1024, free_r / 1024, shared / 1024, buffers / 1024,
        });
        try w.print("Swap:   {d:>12} {d:>12} {d:>12}\n", .{
            swap_total / 1024, swap_used / 1024, swap_free / 1024,
        });
    }
    try w.flush();
}

fn formatBytes(buf: []u8, size: u64) []const u8 {
    const units = [_][]const u8{ "B", "K", "M", "G", "T" };
    var s: f64 = @floatFromInt(size);
    var u: usize = 0;
    while (s >= 1024.0 and u + 1 < units.len) : (u += 1) {
        s /= 1024.0;
    }
    if (u == 0) return std.fmt.bufPrint(buf, "{d}{s}", .{ size, units[u] }) catch "?";
    if (s >= 10.0) return std.fmt.bufPrint(buf, "{d:.0}{s}", .{ s, units[u] }) catch "?";
    return std.fmt.bufPrint(buf, "{d:.1}{s}", .{ s, units[u] }) catch "?";
}

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

pub fn cmdKill(io: Io, args: []const [:0]const u8) !void {
    var sig: posix.SIG = .TERM;
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        const a = args[i];
        if (mem.eql(u8, a, "-l")) {
            try util.writeAll(io, .stdout(), "1 HUP 2 INT 3 QUIT 9 KILL 15 TERM\n");
            return;
        }
        // -SIGNAL or -N
        const s = a[1..];
        if (std.fmt.parseInt(u8, s, 10)) |n| {
            sig = @enumFromInt(n);
        } else |_| {
            if (mem.eql(u8, s, "TERM") or mem.eql(u8, s, "term")) sig = .TERM
            else if (mem.eql(u8, s, "KILL") or mem.eql(u8, s, "kill") or mem.eql(u8, s, "9")) sig = .KILL
            else if (mem.eql(u8, s, "HUP") or mem.eql(u8, s, "hup") or mem.eql(u8, s, "1")) sig = .HUP
            else if (mem.eql(u8, s, "INT") or mem.eql(u8, s, "int") or mem.eql(u8, s, "2")) sig = .INT
            else if (mem.eql(u8, s, "QUIT") or mem.eql(u8, s, "quit")) sig = .QUIT
            else if (mem.eql(u8, s, "0") or mem.eql(u8, s, "NULL")) sig = @enumFromInt(0)
            else {
                var buf: [64]u8 = undefined;
                const msg = try std.fmt.bufPrint(&buf, "kill: unknown signal: {s}\n", .{s});
                try util.writeAll(io, .stderr(), msg);
                std.process.exit(1);
            }
        }
    }
    if (i >= args.len) {
        try util.writeAll(io, .stderr(), "kill: missing pid\n");
        std.process.exit(1);
    }
    while (i < args.len) : (i += 1) {
        const pid = std.fmt.parseInt(posix.pid_t, args[i], 10) catch {
            var buf: [64]u8 = undefined;
            const msg = try std.fmt.bufPrint(&buf, "kill: invalid pid: {s}\n", .{args[i]});
            try util.writeAll(io, .stderr(), msg);
            std.process.exit(1);
        };
        posix.kill(pid, sig) catch |err| {
            var buf: [128]u8 = undefined;
            const msg = try std.fmt.bufPrint(&buf, "kill: ({d}): {s}\n", .{ pid, @errorName(err) });
            try util.writeAll(io, .stderr(), msg);
            std.process.exit(1);
        };
    }
}

pub fn cmdNproc(io: Io, args: []const [:0]const u8) !void {
    _ = args;
    const n = std.Thread.getCpuCount() catch 1;
    var buf: [32]u8 = undefined;
    const s = try std.fmt.bufPrint(&buf, "{d}\n", .{n});
    try util.writeAll(io, .stdout(), s);
}

pub fn cmdSync(io: Io, args: []const [:0]const u8) !void {
    _ = args;
    std.os.linux.sync();
    _ = io;
}

pub fn cmdArch(io: Io, args: []const [:0]const u8) !void {
    _ = args;
    const arch = @tagName(builtin.cpu.arch);
    try util.writeAll(io, .stdout(), arch);
    try util.writeAll(io, .stdout(), "\n");
}

pub fn cmdClear(io: Io) !void {
    try util.writeAll(io, .stdout(), "\x1b[2J\x1b[H");
}

pub fn cmdTest(io: Io, args: []const [:0]const u8) !void {
    // POSIX test / [  — subset of expressions
    // Exit 0 if true, 1 if false, 2 on error
    if (args.len < 2) {
        std.process.exit(1);
    }
    // Drop trailing ] when invoked as [
    const end = if (mem.eql(u8, args[args.len - 1], "]")) args.len - 1 else args.len;
    if (end < 2) {
        std.process.exit(1);
    }
    const a = args[1..end];

    const ok = evalTest(io, a) catch {
        std.process.exit(2);
    };
    std.process.exit(if (ok) 0 else 1);
}

fn evalTest(io: Io, a: []const [:0]const u8) !bool {
    if (a.len == 0) return false;

    // Unary: -z / -n STRING
    if (a.len == 1) {
        return a[0].len != 0; // [ STRING ] is true if non-empty
    }

    if (a.len == 2) {
        const op = a[0];
        const arg = a[1];
        if (mem.eql(u8, op, "-z")) return arg.len == 0;
        if (mem.eql(u8, op, "-n")) return arg.len != 0;
        if (mem.eql(u8, op, "-e")) return pathExists(io, arg);
        if (mem.eql(u8, op, "-f")) return pathIsKind(io, arg, .file);
        if (mem.eql(u8, op, "-d")) return pathIsKind(io, arg, .directory);
        if (mem.eql(u8, op, "-L") or mem.eql(u8, op, "-h")) return pathIsKind(io, arg, .sym_link);
        if (mem.eql(u8, op, "-b")) return pathIsKind(io, arg, .block_device);
        if (mem.eql(u8, op, "-c")) return pathIsKind(io, arg, .character_device);
        if (mem.eql(u8, op, "-p")) return pathIsKind(io, arg, .named_pipe);
        if (mem.eql(u8, op, "-S")) return pathIsKind(io, arg, .unix_domain_socket);
        if (mem.eql(u8, op, "-s")) {
            const st = Io.Dir.cwd().statFile(io, arg, .{}) catch return false;
            return st.size > 0;
        }
        if (mem.eql(u8, op, "-r")) {
            Io.Dir.cwd().access(io, arg, .{ .read = true }) catch return false;
            return true;
        }
        if (mem.eql(u8, op, "-w")) {
            Io.Dir.cwd().access(io, arg, .{ .write = true }) catch return false;
            return true;
        }
        if (mem.eql(u8, op, "-x")) {
            Io.Dir.cwd().access(io, arg, .{ .execute = true }) catch return false;
            return true;
        }
        // unknown unary → treat as [ STRING ] style with two tokens? false
        return false;
    }

    if (a.len == 3) {
        const left = a[0];
        const op = a[1];
        const right = a[2];
        // string compares
        if (mem.eql(u8, op, "=") or mem.eql(u8, op, "==")) return mem.eql(u8, left, right);
        if (mem.eql(u8, op, "!=")) return !mem.eql(u8, left, right);
        // integer compares
        if (mem.eql(u8, op, "-eq") or mem.eql(u8, op, "-ne") or mem.eql(u8, op, "-lt") or
            mem.eql(u8, op, "-le") or mem.eql(u8, op, "-gt") or mem.eql(u8, op, "-ge"))
        {
            const l = std.fmt.parseInt(i64, left, 10) catch return false;
            const r = std.fmt.parseInt(i64, right, 10) catch return false;
            if (mem.eql(u8, op, "-eq")) return l == r;
            if (mem.eql(u8, op, "-ne")) return l != r;
            if (mem.eql(u8, op, "-lt")) return l < r;
            if (mem.eql(u8, op, "-le")) return l <= r;
            if (mem.eql(u8, op, "-gt")) return l > r;
            if (mem.eql(u8, op, "-ge")) return l >= r;
        }
        return false;
    }

    // [ ! EXPR ]
    if (a.len >= 2 and mem.eql(u8, a[0], "!")) {
        return !(try evalTest(io, a[1..]));
    }

    return false;
}

fn pathExists(io: Io, path: []const u8) bool {
    Io.Dir.cwd().access(io, path, .{}) catch return false;
    return true;
}

fn pathIsKind(io: Io, path: []const u8, kind: Io.File.Kind) bool {
    // For symlinks, do not follow
    const follow = kind != .sym_link;
    const st = Io.Dir.cwd().statFile(io, path, .{ .follow_symlinks = follow }) catch return false;
    return st.kind == kind;
}

pub fn cmdEnv(io: Io, args: []const [:0]const u8, environ: *process.Environ.Map) !void {
    // printenv NAME  or  env   or  env KEY=VAL ...
    var buf: [4096]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &buf);
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


pub fn cmdWhich(io: Io, arena: mem.Allocator, args: []const [:0]const u8, environ: *process.Environ.Map) !void {
    if (args.len < 2) {
        try util.writeAll(io, .stderr(), "which: missing operand\n");
        std.process.exit(1);
    }

    const path_env = environ.get("PATH") orelse "/bin:/usr/bin";
    var found_any = false;
    var failed = false;

    var wbuf: [4096]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const w = &writer.interface;

    for (args[1..]) |name| {
        // If name contains '/', check as path
        if (mem.indexOfScalar(u8, name, '/') != null) {
            Io.Dir.cwd().access(io, name, .{ .execute = true }) catch {
                failed = true;
                continue;
            };
            try w.writeAll(name);
            try w.writeAll("\n");
            found_any = true;
            continue;
        }

        var path_iter = mem.splitScalar(u8, path_env, ':');
        var hit = false;
        while (path_iter.next()) |dir| {
            if (dir.len == 0) continue;
            const candidate = try std.fmt.allocPrint(arena, "{s}/{s}", .{ dir, name });
            defer arena.free(candidate);
            Io.Dir.cwd().access(io, candidate, .{ .execute = true }) catch continue;
            try w.writeAll(candidate);
            try w.writeAll("\n");
            hit = true;
            found_any = true;
            break;
        }
        if (!hit) failed = true;
    }
    try w.flush();
    if (failed or !found_any) std.process.exit(1);
}


