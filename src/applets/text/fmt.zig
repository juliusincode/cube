const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdFmt(io: Io, args: []const [:0]const u8) !void {
    // fmt [-w WIDTH] [FILE]...  — simple paragraph refill
    var width: usize = 75;
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        const a = args[i];
        if (mem.eql(u8, a, "-w") and i + 1 < args.len) {
            i += 1;
            width = std.fmt.parseInt(usize, args[i], 10) catch 75;
        } else if (a.len > 2 and a[0] == '-' and a[1] == 'w') {
            width = std.fmt.parseInt(usize, a[2..], 10) catch 75;
        }
    }
    if (width == 0) width = 75;

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
                const msg = try std.fmt.bufPrint(&buf, "fmt: {s}: {s}\n", .{ path, @errorName(err) });
                try util.writeAll(io, .stderr(), msg);
                continue;
            };
        defer if (!mem.eql(u8, path, "-")) file.close(io);

        var rbuf: [8192]u8 = undefined;
        var reader: Io.File.Reader = .init(file, io, &rbuf);
        var col: usize = 0;

        while (true) {
            const line = (reader.interface.takeDelimiter('\n') catch break) orelse break;
            // blank line → paragraph break
            if (line.len == 0) {
                if (col > 0) {
                    try w.writeAll("\n");
                    col = 0;
                }
                try w.writeAll("\n");
                continue;
            }
            var it = mem.tokenizeAny(u8, line, " \t");
            while (it.next()) |word| {
                if (col == 0) {
                    try w.writeAll(word);
                    col = word.len;
                } else if (col + 1 + word.len <= width) {
                    try w.writeAll(" ");
                    try w.writeAll(word);
                    col += 1 + word.len;
                } else {
                    try w.writeAll("\n");
                    try w.writeAll(word);
                    col = word.len;
                }
            }
        }
        if (col > 0) try w.writeAll("\n");
    }
    try w.flush();
}
