const std = @import("std");
const Io = std.Io;
const mem = std.mem;

pub fn basename(path: []const u8) []const u8 {
    if (mem.lastIndexOfScalar(u8, path, '/')) |idx| {
        return path[idx + 1 ..];
    }
    return path;
}

pub fn writeAll(io: Io, file: Io.File, data: []const u8) !void {
    var buf: [4096]u8 = undefined;
    // stdout/stderr must be streaming; positional would overwrite from offset 0
    var writer: Io.File.Writer = .initStreaming(file, io, &buf);
    try writer.interface.writeAll(data);
    try writer.interface.flush();
}

pub fn writeAllNoFlush(io: Io, file: Io.File, data: []const u8) !void {
    var buf: [4096]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(file, io, &buf);
    try writer.interface.writeAll(data);
}

pub fn copyFile(io: Io, src: Io.File, dst: Io.File) !void {
    var rbuf: [8192]u8 = undefined;
    var reader: Io.File.Reader = .init(src, io, &rbuf);
    var wbuf: [8192]u8 = undefined;
    // Use streaming for stdout/stderr so sequential writes append
    const is_stdio = dst.handle == Io.File.stdout().handle or dst.handle == Io.File.stderr().handle;
    var writer: Io.File.Writer = if (is_stdio)
        .initStreaming(dst, io, &wbuf)
    else
        .init(dst, io, &wbuf);
    while (true) {
        const n = reader.interface.readSliceShort(&rbuf) catch |err| return err;
        if (n == 0) break;
        try writer.interface.writeAll(rbuf[0..n]);
    }
    try writer.interface.flush();
}

test "basename basic" {
    try std.testing.expectEqualStrings("file.txt", basename("file.txt"));
    try std.testing.expectEqualStrings("file.txt", basename("/tmp/file.txt"));
    try std.testing.expectEqualStrings("file.txt", basename("/a/b/c/file.txt"));
    try std.testing.expectEqualStrings("", basename("/tmp/"));
    try std.testing.expectEqualStrings("tmp", basename("/tmp"));
    try std.testing.expectEqualStrings(".", basename("."));
}

test "basename edge cases" {
    try std.testing.expectEqualStrings("", basename(""));
    try std.testing.expectEqualStrings("a", basename("a"));
    try std.testing.expectEqualStrings("z", basename("x/y/z"));
}
