const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdRev(io: Io, args: []const [:0]const u8) !void {
    const files: []const [:0]const u8 = if (args.len <= 1)
        &[_][:0]const u8{"-"}
    else
        args[1..];

    var wbuf: [8192]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const w = &writer.interface;

    for (files) |path| {
        const file = if (mem.eql(u8, path, "-"))
            Io.File.stdin()
        else
            Io.Dir.cwd().openFile(io, path, .{}) catch |err| {
                var buf: [256]u8 = undefined;
                const msg = try std.fmt.bufPrint(&buf, "rev: {s}: {s}\n", .{ path, @errorName(err) });
                try util.writeAll(io, .stderr(), msg);
                continue;
            };
        defer if (!mem.eql(u8, path, "-")) file.close(io);

        var rbuf: [8192]u8 = undefined;
        var reader: Io.File.Reader = .init(file, io, &rbuf);
        while (true) {
            const line = (reader.interface.takeDelimiter('\n') catch |err| return err) orelse break;
            // reverse bytes
            var j: usize = line.len;
            while (j > 0) {
                j -= 1;
                try w.writeAll(line[j .. j + 1]);
            }
            try w.writeAll("\n");
        }
    }
    try w.flush();
}
