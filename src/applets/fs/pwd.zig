const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdPwd(io: Io, arena: mem.Allocator) !void {
    const cwd = try process.currentPathAlloc(io, arena);
    defer arena.free(cwd);
    try util.writeAll(io, .stdout(), cwd);
    try util.writeAll(io, .stdout(), "\n");
}
