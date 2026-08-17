const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

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
