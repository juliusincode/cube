const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdCksum(io: Io, args: []const [:0]const u8) !void {
    // cksum [FILE]...  — CRC32 and byte count (Zig std.hash.Crc32)
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {}
    const paths: []const [:0]const u8 = if (i >= args.len)
        &[_][:0]const u8{"-"}
    else
        args[i..];

    var wbuf: [512]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const w = &writer.interface;

    for (paths) |path| {
        const file = if (mem.eql(u8, path, "-"))
            Io.File.stdin()
        else
            Io.Dir.cwd().openFile(io, path, .{}) catch |err| {
                var buf: [256]u8 = undefined;
                const msg = try std.fmt.bufPrint(&buf, "cksum: {s}: {s}\n", .{ path, @errorName(err) });
                try util.writeAll(io, .stderr(), msg);
                continue;
            };
        defer if (!mem.eql(u8, path, "-")) file.close(io);

        var rbuf: [8192]u8 = undefined;
        var reader: Io.File.Reader = .init(file, io, &rbuf);
        var crc = std.hash.Crc32.init();
        var size: u64 = 0;
        var chunk: [8192]u8 = undefined;
        while (true) {
            const n = reader.interface.readSliceShort(&chunk) catch break;
            if (n == 0) break;
            crc.update(chunk[0..n]);
            size += n;
        }
        try w.print("{d} {d} {s}\n", .{ crc.final(), size, path });
    }
    try w.flush();
}
