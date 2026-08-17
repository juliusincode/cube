const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdCmp(io: Io, args: []const [:0]const u8) !void {
    // cmp [-s] FILE1 FILE2
    var silent = false;
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        for (args[i][1..]) |c| {
            if (c == 's') silent = true;
        }
    }
    if (i + 1 >= args.len) {
        try util.writeAll(io, .stderr(), "cmp: missing operand\n");
        std.process.exit(2);
    }
    const p1 = args[i];
    const p2 = args[i + 1];

    const f1 = if (mem.eql(u8, p1, "-"))
        Io.File.stdin()
    else
        Io.Dir.cwd().openFile(io, p1, .{}) catch |err| {
            var buf: [256]u8 = undefined;
            const msg = try std.fmt.bufPrint(&buf, "cmp: {s}: {s}\n", .{ p1, @errorName(err) });
            try util.writeAll(io, .stderr(), msg);
            std.process.exit(2);
        };
    defer if (!mem.eql(u8, p1, "-")) f1.close(io);

    const f2 = Io.Dir.cwd().openFile(io, p2, .{}) catch |err| {
        var buf: [256]u8 = undefined;
        const msg = try std.fmt.bufPrint(&buf, "cmp: {s}: {s}\n", .{ p2, @errorName(err) });
        try util.writeAll(io, .stderr(), msg);
        std.process.exit(2);
    };
    defer f2.close(io);

    var rbuf1: [4096]u8 = undefined;
    var rbuf2: [4096]u8 = undefined;
    var r1: Io.File.Reader = .init(f1, io, &rbuf1);
    var r2: Io.File.Reader = .init(f2, io, &rbuf2);

    var pos: u64 = 1;
    var line: u64 = 1;
    var b1: [1]u8 = undefined;
    var b2: [1]u8 = undefined;

    while (true) {
        const n1 = r1.interface.readSliceShort(&b1) catch return;
        const n2 = r2.interface.readSliceShort(&b2) catch return;
        if (n1 == 0 and n2 == 0) return; // equal
        if (n1 == 0 or n2 == 0 or b1[0] != b2[0]) {
            if (!silent) {
                var buf: [128]u8 = undefined;
                const msg = try std.fmt.bufPrint(&buf, "{s} {s} differ: byte {d}, line {d}\n", .{ p1, p2, pos, line });
                try util.writeAll(io, .stderr(), msg);
            }
            std.process.exit(1);
        }
        if (b1[0] == '\n') line += 1;
        pos += 1;
    }
}
