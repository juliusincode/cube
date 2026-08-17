const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdStrings(io: Io, args: []const [:0]const u8) !void {
    // strings [-n N] [FILE]...  — printable sequences (min length N, default 4)
    var min_len: usize = 4;
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        const a = args[i];
        if (mem.eql(u8, a, "-n") and i + 1 < args.len) {
            i += 1;
            min_len = std.fmt.parseInt(usize, args[i], 10) catch 4;
        } else if (a.len > 2 and a[0] == '-' and a[1] == 'n') {
            min_len = std.fmt.parseInt(usize, a[2..], 10) catch 4;
        }
    }
    const paths: []const [:0]const u8 = if (i >= args.len)
        &[_][:0]const u8{"-"}
    else
        args[i..];

    var wbuf: [8192]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const w = &writer.interface;

    for (paths) |path| {
        const file = if (mem.eql(u8, path, "-"))
            Io.File.stdin()
        else
            Io.Dir.cwd().openFile(io, path, .{}) catch |err| {
                var buf: [256]u8 = undefined;
                const msg = try std.fmt.bufPrint(&buf, "strings: {s}: {s}\n", .{ path, @errorName(err) });
                try util.writeAll(io, .stderr(), msg);
                continue;
            };
        defer if (!mem.eql(u8, path, "-")) file.close(io);

        var rbuf: [8192]u8 = undefined;
        var reader: Io.File.Reader = .init(file, io, &rbuf);
        var acc: [4096]u8 = undefined;
        var acc_len: usize = 0;

        while (true) {
            var tmp: [1]u8 = undefined;
            const n = reader.interface.readSliceShort(&tmp) catch break;
            if (n == 0) break;
            const c = tmp[0];
            if (c >= 32 and c < 127) {
                if (acc_len < acc.len) {
                    acc[acc_len] = c;
                    acc_len += 1;
                }
            } else {
                if (acc_len >= min_len) {
                    try w.writeAll(acc[0..acc_len]);
                    try w.writeAll("\n");
                }
                acc_len = 0;
            }
        }
        if (acc_len >= min_len) {
            try w.writeAll(acc[0..acc_len]);
            try w.writeAll("\n");
        }
    }
    try w.flush();
}
