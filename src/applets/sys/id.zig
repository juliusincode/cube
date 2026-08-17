const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const posix = std.posix;
const util = @import("util");

pub fn cmdId(io: Io) !void {
    const uid = std.os.linux.getuid();
    const gid = std.os.linux.getgid();
    const euid = std.os.linux.geteuid();
    const egid = std.os.linux.getegid();
    var buf: [128]u8 = undefined;
    const msg = if (uid == euid and gid == egid)
        try std.fmt.bufPrint(&buf, "uid={d} gid={d}\n", .{ uid, gid })
    else
        try std.fmt.bufPrint(&buf, "uid={d} gid={d} euid={d} egid={d}\n", .{ uid, gid, euid, egid });
    try util.writeAll(io, .stdout(), msg);
}
