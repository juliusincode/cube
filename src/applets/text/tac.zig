const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdTac(io: Io, arena: mem.Allocator, args: []const [:0]const u8) !void {
    // tac [FILE]... — print lines in reverse order
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {}
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
                const msg = try std.fmt.bufPrint(&buf, "tac: {s}: {s}\n", .{ path, @errorName(err) });
                try util.writeAll(io, .stderr(), msg);
                continue;
            };
        defer if (!mem.eql(u8, path, "-")) file.close(io);

        var lines: std.ArrayListUnmanaged([]const u8) = .empty;
        defer {
            for (lines.items) |ln| arena.free(ln);
            lines.deinit(arena);
        }

        var rbuf: [8192]u8 = undefined;
        var reader: Io.File.Reader = .init(file, io, &rbuf);
        while (true) {
            const line = (reader.interface.takeDelimiter('\n') catch break) orelse break;
            try lines.append(arena, try arena.dupe(u8, line));
        }
        var idx = lines.items.len;
        while (idx > 0) {
            idx -= 1;
            try w.writeAll(lines.items[idx]);
            try w.writeAll("\n");
        }
    }
    try w.flush();
}
