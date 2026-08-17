const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

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
