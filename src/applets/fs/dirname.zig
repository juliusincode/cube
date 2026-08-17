const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdDirname(io: Io, args: []const [:0]const u8) !void {
    if (args.len < 2) {
        try util.writeAll(io, .stderr(), "dirname: missing operand\n");
        std.process.exit(1);
    }
    var ai: usize = 1;
    while (ai < args.len) : (ai += 1) {
        const p = args[ai];
        if (mem.lastIndexOfScalar(u8, p, '/')) |idx| {
            if (idx == 0) {
                try util.writeAll(io, .stdout(), "/\n");
            } else {
                try util.writeAll(io, .stdout(), p[0..idx]);
                try util.writeAll(io, .stdout(), "\n");
            }
        } else {
            try util.writeAll(io, .stdout(), ".\n");
        }
    }
}
