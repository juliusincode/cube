const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdNl(io: Io, args: []const [:0]const u8) !void {
    // nl [-b a|t] [FILE]...  — number lines (a=all, t=non-empty; default t)
    var number_all = false;
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        const a = args[i];
        if (mem.eql(u8, a, "-b") and i + 1 < args.len) {
            i += 1;
            number_all = (args[i].len > 0 and args[i][0] == 'a');
        } else if (mem.eql(u8, a, "-ba")) {
            number_all = true;
        } else if (mem.eql(u8, a, "-bt")) {
            number_all = false;
        }
    }
    const paths: []const [:0]const u8 = if (i >= args.len)
        &[_][:0]const u8{"-"}
    else
        args[i..];

    var wbuf: [8192]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const w = &writer.interface;

    var line_no: u64 = 1;
    for (paths) |path| {
        const file = if (mem.eql(u8, path, "-"))
            Io.File.stdin()
        else
            Io.Dir.cwd().openFile(io, path, .{}) catch |err| {
                var buf: [256]u8 = undefined;
                const msg = try std.fmt.bufPrint(&buf, "nl: {s}: {s}\n", .{ path, @errorName(err) });
                try util.writeAll(io, .stderr(), msg);
                continue;
            };
        defer if (!mem.eql(u8, path, "-")) file.close(io);

        var rbuf: [8192]u8 = undefined;
        var reader: Io.File.Reader = .init(file, io, &rbuf);
        while (true) {
            const line = (reader.interface.takeDelimiter('\n') catch break) orelse break;
            if (number_all or line.len > 0) {
                try w.print("{d:>6}\t{s}\n", .{ line_no, line });
                line_no += 1;
            } else {
                try w.writeAll("\n");
            }
        }
    }
    try w.flush();
}
