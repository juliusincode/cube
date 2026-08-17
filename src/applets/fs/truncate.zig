const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

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
