const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdSum(io: Io, args: []const [:0]const u8) !void {
    // sum [FILE]...  — simple 16-bit checksum and block count (BSD-ish)
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {}
    const paths: []const [:0]const u8 = if (i >= args.len)
        &[_][:0]const u8{"-"}
    else
        args[i..];

    var wbuf: [256]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const w = &writer.interface;

    for (paths) |path| {
        const file = if (mem.eql(u8, path, "-"))
            Io.File.stdin()
        else
            Io.Dir.cwd().openFile(io, path, .{}) catch |err| {
                var buf: [256]u8 = undefined;
                const msg = try std.fmt.bufPrint(&buf, "sum: {s}: {s}\n", .{ path, @errorName(err) });
                try util.writeAll(io, .stderr(), msg);
                continue;
            };
        defer if (!mem.eql(u8, path, "-")) file.close(io);

        var rbuf: [8192]u8 = undefined;
        var reader: Io.File.Reader = .init(file, io, &rbuf);
        var checksum: u16 = 0;
        var size: u64 = 0;
        var chunk: [8192]u8 = undefined;
        while (true) {
            const n = reader.interface.readSliceShort(&chunk) catch break;
            if (n == 0) break;
            for (chunk[0..n]) |b| {
                // BSD rotate-and-add
                checksum = (checksum >> 1) +% ((checksum & 1) << 15);
                checksum +%= b;
            }
            size += n;
        }
        const blocks = (size + 511) / 512;
        if (mem.eql(u8, path, "-")) {
            try w.print("{d:0>5} {d}\n", .{ checksum, blocks });
        } else {
            try w.print("{d:0>5} {d} {s}\n", .{ checksum, blocks, path });
        }
    }
    try w.flush();
}
