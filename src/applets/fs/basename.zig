const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdBasename(io: Io, args: []const [:0]const u8) !void {
    // basename NAME [SUFFIX]
    if (args.len < 2) {
        try util.writeAll(io, .stderr(), "basename: missing operand\n");
        std.process.exit(1);
    }
    var base = util.basename(args[1]);
    if (args.len >= 3) {
        const suf = args[2];
        if (suf.len > 0 and base.len >= suf.len and mem.eql(u8, base[base.len - suf.len ..], suf)) {
            base = base[0 .. base.len - suf.len];
        }
    }
    try util.writeAll(io, .stdout(), base);
    try util.writeAll(io, .stdout(), "\n");
}
