const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdExpand(io: Io, args: []const [:0]const u8) !void {
    // expand [-t N] [FILE]...  — tabs to spaces (default tab stops every 8)
    var tab: usize = 8;
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        const a = args[i];
        if (mem.eql(u8, a, "-t") and i + 1 < args.len) {
            i += 1;
            tab = std.fmt.parseInt(usize, args[i], 10) catch 8;
        } else if (a.len > 2 and a[0] == '-' and a[1] == 't') {
            tab = std.fmt.parseInt(usize, a[2..], 10) catch 8;
        }
    }
    if (tab == 0) tab = 8;

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
                const msg = try std.fmt.bufPrint(&buf, "expand: {s}: {s}\n", .{ path, @errorName(err) });
                try util.writeAll(io, .stderr(), msg);
                continue;
            };
        defer if (!mem.eql(u8, path, "-")) file.close(io);

        var rbuf: [8192]u8 = undefined;
        var reader: Io.File.Reader = .init(file, io, &rbuf);
        var col: usize = 0;
        while (true) {
            var tmp: [1]u8 = undefined;
            const n = reader.interface.readSliceShort(&tmp) catch break;
            if (n == 0) break;
            const c = tmp[0];
            if (c == '\t') {
                const spaces = tab - (col % tab);
                var s: usize = 0;
                while (s < spaces) : (s += 1) {
                    try w.writeAll(" ");
                    col += 1;
                }
            } else {
                try w.writeAll(&.{c});
                if (c == '\n') col = 0 else col += 1;
            }
        }
    }
    try w.flush();
}
