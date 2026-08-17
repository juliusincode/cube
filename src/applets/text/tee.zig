const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdTee(io: Io, args: []const [:0]const u8) !void {
    // tee [-a] [FILE]...
    var append = false;
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        const a = args[i];
        if (mem.eql(u8, a, "--")) {
            i += 1;
            break;
        }
        for (a[1..]) |c| {
            if (c == 'a') append = true;
        }
    }

    const paths = args[i..];
    var files: [16]?Io.File = [_]?Io.File{null} ** 16;
    var offsets: [16]u64 = [_]u64{0} ** 16;
    var nfiles: usize = 0;

    for (paths) |path| {
        if (nfiles >= files.len) break;
        const f = Io.Dir.cwd().createFile(io, path, .{ .truncate = !append }) catch |err| {
            var buf: [256]u8 = undefined;
            const msg = try std.fmt.bufPrint(&buf, "tee: {s}: {s}\n", .{ path, @errorName(err) });
            try util.writeAll(io, .stderr(), msg);
            continue;
        };
        if (append) {
            offsets[nfiles] = f.length(io) catch 0;
        }
        files[nfiles] = f;
        nfiles += 1;
    }
    defer {
        var fi: usize = 0;
        while (fi < nfiles) : (fi += 1) {
            if (files[fi]) |f| f.close(io);
        }
    }

    var rbuf: [8192]u8 = undefined;
    var reader: Io.File.Reader = .init(.stdin(), io, &rbuf);
    var outbuf: [8192]u8 = undefined;

    var wbuf: [8192]u8 = undefined;
    var stdout_w: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const out = &stdout_w.interface;

    while (true) {
        const n = reader.interface.readSliceShort(&outbuf) catch |err| return err;
        if (n == 0) break;
        try out.writeAll(outbuf[0..n]);
        var fi: usize = 0;
        while (fi < nfiles) : (fi += 1) {
            if (files[fi]) |f| {
                if (append) {
                    f.writePositionalAll(io, outbuf[0..n], offsets[fi]) catch {};
                    offsets[fi] += n;
                } else {
                    var fbuf: [8192]u8 = undefined;
                    var fw: Io.File.Writer = .initStreaming(f, io, &fbuf);
                    fw.interface.writeAll(outbuf[0..n]) catch {};
                    fw.interface.flush() catch {};
                }
            }
        }
    }
    try out.flush();
}
