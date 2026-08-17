const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdYes(io: Io, args: []const [:0]const u8) !void {
    const str = if (args.len > 1) args[1] else "y";
    var buf: [4096]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &buf);
    const w = &writer.interface;
    while (true) {
        try w.writeAll(str);
        try w.writeAll("\n");
        try w.flush();
    }
}
