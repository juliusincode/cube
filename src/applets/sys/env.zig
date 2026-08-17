const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const posix = std.posix;
const util = @import("util");

pub fn cmdEnv(io: Io, args: []const [:0]const u8, environ: *process.Environ.Map) !void {
    // printenv NAME  or  env   or  env KEY=VAL ...
    var buf: [4096]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &buf);
    const w = &writer.interface;

    if (args.len >= 2 and !mem.eql(u8, args[0], "env")) {
        // printenv VAR
        const key = args[1];
        if (environ.get(key)) |val| {
            try w.writeAll(val);
            try w.writeAll("\n");
        } else {
            std.process.exit(1);
        }
        try w.flush();
        return;
    }

    // env with no args → print all
    // simple: iterate map if API allows
    var it = environ.iterator();
    while (it.next()) |entry| {
        try w.writeAll(entry.key_ptr.*);
        try w.writeAll("=");
        try w.writeAll(entry.value_ptr.*);
        try w.writeAll("\n");
    }
    try w.flush();
}
