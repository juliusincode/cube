const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdSeq(io: Io, args: []const [:0]const u8) !void {
    if (args.len < 2) {
        try util.writeAll(io, .stderr(), "seq: missing operand\n");
        std.process.exit(1);
    }
    var start: i64 = 1;
    var step: i64 = 1;
    var end: i64 = undefined;
    if (args.len == 2) {
        end = std.fmt.parseInt(i64, args[1], 10) catch {
            try util.writeAll(io, .stderr(), "seq: invalid\n");
            std.process.exit(1);
        };
    } else if (args.len == 3) {
        start = std.fmt.parseInt(i64, args[1], 10) catch 1;
        end = std.fmt.parseInt(i64, args[2], 10) catch {
            try util.writeAll(io, .stderr(), "seq: invalid\n");
            std.process.exit(1);
        };
    } else {
        start = std.fmt.parseInt(i64, args[1], 10) catch 1;
        step = std.fmt.parseInt(i64, args[2], 10) catch 1;
        end = std.fmt.parseInt(i64, args[3], 10) catch {
            try util.writeAll(io, .stderr(), "seq: invalid\n");
            std.process.exit(1);
        };
    }
    var buf: [4096]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &buf);
    const w = &writer.interface;
    var i = start;
    while ((step > 0 and i <= end) or (step < 0 and i >= end)) : (i += step) {
        try w.print("{d}\n", .{i});
    }
    try w.flush();
}
