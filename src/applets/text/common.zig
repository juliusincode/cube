const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub const HashKind = enum { md5, sha256 };

pub fn hashSum(io: Io, args: []const [:0]const u8, kind: HashKind) !void {
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
                const msg = try std.fmt.bufPrint(&buf, "{s}: {s}: {s}\n", .{
                    if (kind == .md5) "md5sum" else "sha256sum",
                    path,
                    @errorName(err),
                });
                try util.writeAll(io, .stderr(), msg);
                continue;
            };
        defer if (!mem.eql(u8, path, "-")) file.close(io);

        var rbuf: [8192]u8 = undefined;
        var reader: Io.File.Reader = .init(file, io, &rbuf);
        var chunk: [8192]u8 = undefined;

        switch (kind) {
            .md5 => {
                var h = std.crypto.hash.Md5.init(.{});
                while (true) {
                    const n = reader.interface.readSliceShort(&chunk) catch |err| return err;
                    if (n == 0) break;
                    h.update(chunk[0..n]);
                }
                var digest: [std.crypto.hash.Md5.digest_length]u8 = undefined;
                h.final(&digest);
                try writeHex(w, &digest);
            },
            .sha256 => {
                var h = std.crypto.hash.sha2.Sha256.init(.{});
                while (true) {
                    const n = reader.interface.readSliceShort(&chunk) catch |err| return err;
                    if (n == 0) break;
                    h.update(chunk[0..n]);
                }
                var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
                h.final(&digest);
                try writeHex(w, &digest);
            },
        }
        try w.print("  {s}\n", .{path});
    }
    try w.flush();
}

pub fn writeHex(w: anytype, bytes: []const u8) !void {
    const hex = "0123456789abcdef";
    for (bytes) |b| {
        try w.writeAll(&.{ hex[b >> 4], hex[b & 0xf] });
    }
}

pub fn readAllLines(io: Io, arena: mem.Allocator, path: []const u8) ![][]const u8 {
    const file = if (mem.eql(u8, path, "-"))
        Io.File.stdin()
    else
        try Io.Dir.cwd().openFile(io, path, .{});
    defer if (!mem.eql(u8, path, "-")) file.close(io);

    var list: std.ArrayListUnmanaged([]const u8) = .empty;
    errdefer freeLines(arena, list.items);

    var rbuf: [8192]u8 = undefined;
    var reader: Io.File.Reader = .init(file, io, &rbuf);
    while (true) {
        const line = (reader.interface.takeDelimiter('\n') catch break) orelse break;
        try list.append(arena, try arena.dupe(u8, line));
    }
    return try list.toOwnedSlice(arena);
}

pub fn freeLines(arena: mem.Allocator, lines: [][]const u8) void {
    for (lines) |ln| arena.free(ln);
    arena.free(lines);
}
