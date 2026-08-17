const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const posix = std.posix;
const util = @import("util");

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
            if (mem.eql(u8, s, "TERM") or mem.eql(u8, s, "term")) sig = .TERM else if (mem.eql(u8, s, "KILL") or mem.eql(u8, s, "kill") or mem.eql(u8, s, "9")) sig = .KILL else if (mem.eql(u8, s, "HUP") or mem.eql(u8, s, "hup") or mem.eql(u8, s, "1")) sig = .HUP else if (mem.eql(u8, s, "INT") or mem.eql(u8, s, "int") or mem.eql(u8, s, "2")) sig = .INT else if (mem.eql(u8, s, "QUIT") or mem.eql(u8, s, "quit")) sig = .QUIT else if (mem.eql(u8, s, "0") or mem.eql(u8, s, "NULL")) sig = @enumFromInt(0) else {
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
