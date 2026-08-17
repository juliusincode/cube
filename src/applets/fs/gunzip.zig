const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");
const gzip_mod = @import("gzip.zig");

pub fn cmdGunzip(io: Io, args: []const [:0]const u8) !void {
    // gunzip [FILE]... equivalent to gzip -d
    var argv_buf: [64][:0]const u8 = undefined;
    var n: usize = 0;
    argv_buf[n] = "gzip";
    n += 1;
    argv_buf[n] = "-d";
    n += 1;
    var i: usize = 1;
    while (i < args.len and n < argv_buf.len) : (i += 1) {
        argv_buf[n] = args[i];
        n += 1;
    }
    try gzip_mod.cmdGzip(io, argv_buf[0..n]);
}
