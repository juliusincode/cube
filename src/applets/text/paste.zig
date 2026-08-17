const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdPaste(io: Io, arena: mem.Allocator, args: []const [:0]const u8) !void {
    // paste [-d delim] FILE...
    var delim: []const u8 = "\t";
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        const a = args[i];
        if (mem.eql(u8, a, "-d") and i + 1 < args.len) {
            i += 1;
            delim = args[i];
            if (delim.len == 0) delim = "\t";
        }
    }
    if (i >= args.len) {
        try util.writeAll(io, .stderr(), "paste: missing file operand\n");
        std.process.exit(1);
    }

    const nfiles = args.len - i;
    var files = try arena.alloc(?Io.File, nfiles);
    defer {
        for (files) |f| {
            if (f) |ff| ff.close(io);
        }
    }
    var readers = try arena.alloc(?Io.File.Reader, nfiles);
    var rbufs = try arena.alloc([4096]u8, nfiles);
    var done = try arena.alloc(bool, nfiles);
    @memset(done, false);

    for (args[i..], 0..) |path, idx| {
        if (mem.eql(u8, path, "-")) {
            files[idx] = Io.File.stdin();
        } else {
            files[idx] = Io.Dir.cwd().openFile(io, path, .{}) catch |err| {
                var buf: [256]u8 = undefined;
                const msg = try std.fmt.bufPrint(&buf, "paste: {s}: {s}\n", .{ path, @errorName(err) });
                try util.writeAll(io, .stderr(), msg);
                files[idx] = null;
                done[idx] = true;
                continue;
            };
        }
        readers[idx] = Io.File.Reader.init(files[idx].?, io, &rbufs[idx]);
    }

    var wbuf: [8192]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const w = &writer.interface;

    while (true) {
        var any = false;
        for (done) |d| {
            if (!d) any = true;
        }
        if (!any) break;

        var first = true;
        for (0..nfiles) |idx| {
            if (!first) {
                // cycle delim chars like paste
                const di = (idx - 1) % delim.len;
                try w.writeAll(delim[di .. di + 1]);
            }
            first = false;
            if (done[idx] or readers[idx] == null) continue;
            const line = (readers[idx].?.interface.takeDelimiter('\n') catch null) orelse {
                done[idx] = true;
                continue;
            };
            try w.writeAll(line);
        }
        try w.writeAll("\n");
    }
    try w.flush();
}
