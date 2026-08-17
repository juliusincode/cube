const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdLink(io: Io, args: []const [:0]const u8) !void {
    // link TARGET LINK_NAME  — create a hard link
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {}
    if (i + 1 >= args.len) {
        try util.writeAll(io, .stderr(), "link: missing operand\n");
        std.process.exit(1);
    }
    const target = args[i];
    const name = args[i + 1];
    Io.Dir.cwd().hardLink(target, Io.Dir.cwd(), name, io, .{}) catch |err| {
        var buf: [256]u8 = undefined;
        const msg = try std.fmt.bufPrint(&buf, "link: {s}: {s}\n", .{ name, @errorName(err) });
        try util.writeAll(io, .stderr(), msg);
        std.process.exit(1);
    };
}
