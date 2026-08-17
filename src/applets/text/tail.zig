const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdTail(io: Io, arena: mem.Allocator, args: []const [:0]const u8) !void {
    var lines: ?usize = null;
    var bytes: ?usize = null;
    var file_arg: ?[:0]const u8 = null;
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const a = args[i];
        if (mem.eql(u8, a, "-n") and i + 1 < args.len) {
            lines = std.fmt.parseInt(usize, args[i + 1], 10) catch 10;
            i += 1;
        } else if (a.len > 2 and a[0] == '-' and a[1] == 'n') {
            lines = std.fmt.parseInt(usize, a[2..], 10) catch 10;
        } else if (mem.eql(u8, a, "-c") and i + 1 < args.len) {
            bytes = std.fmt.parseInt(usize, args[i + 1], 10) catch 0;
            i += 1;
        } else if (a.len > 2 and a[0] == '-' and a[1] == 'c') {
            bytes = std.fmt.parseInt(usize, a[2..], 10) catch 0;
        } else if (a.len > 1 and a[0] == '-' and a[1] >= '0' and a[1] <= '9') {
            lines = std.fmt.parseInt(usize, a[1..], 10) catch 10;
        } else if (a[0] != '-') {
            file_arg = a;
        }
    }
    if (lines == null and bytes == null) lines = 10;

    const file = if (file_arg) |p|
        Io.Dir.cwd().openFile(io, p, .{}) catch |err| {
            var b: [256]u8 = undefined;
            const msg = try std.fmt.bufPrint(&b, "tail: {s}: {s}\n", .{ p, @errorName(err) });
            try util.writeAll(io, .stderr(), msg);
            return;
        }
    else
        Io.File.stdin();
    defer if (file_arg != null) file.close(io);

    var wbuf: [8192]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const w = &writer.interface;

    if (bytes) |nbyte| {
        // Read all into memory, print last n bytes
        var data: std.ArrayListUnmanaged(u8) = .empty;
        defer data.deinit(arena);
        var rbuf: [8192]u8 = undefined;
        var reader: Io.File.Reader = .init(file, io, &rbuf);
        var outbuf: [8192]u8 = undefined;
        while (true) {
            const n = reader.interface.readSliceShort(&outbuf) catch |err| return err;
            if (n == 0) break;
            try data.appendSlice(arena, outbuf[0..n]);
        }
        const start_i = if (data.items.len > nbyte) data.items.len - nbyte else 0;
        try w.writeAll(data.items[start_i..]);
        try w.flush();
        return;
    }

    const limit = lines.?;
    var list: std.ArrayListUnmanaged([]const u8) = .empty;
    defer {
        for (list.items) |l| arena.free(l);
        list.deinit(arena);
    }

    var rbuf: [4096]u8 = undefined;
    var reader: Io.File.Reader = .init(file, io, &rbuf);
    while (true) {
        const line = (reader.interface.takeDelimiter('\n') catch |err| return err) orelse break;
        const owned = try arena.dupe(u8, line);
        try list.append(arena, owned);
        if (list.items.len > limit) {
            arena.free(list.orderedRemove(0));
        }
    }
    for (list.items) |l| {
        try w.writeAll(l);
        try w.writeAll("\n");
    }
    try w.flush();
}
