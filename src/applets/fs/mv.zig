const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdMv(io: Io, args: []const [:0]const u8) !void {
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        if (mem.eql(u8, args[i], "--")) {
            i += 1;
            break;
        }
        // -v/-f ignored for now
    }
    if (i + 1 >= args.len) {
        try util.writeAll(io, .stderr(), "mv: missing file operand\n");
        std.process.exit(1);
    }
    const operands = args[i..];
    const dest = operands[operands.len - 1];
    const sources = operands[0 .. operands.len - 1];

    const dest_is_dir = blk: {
        const st = Io.Dir.cwd().statFile(io, dest, .{}) catch break :blk false;
        break :blk st.kind == .directory;
    };

    if (sources.len > 1 and !dest_is_dir) {
        try util.writeAll(io, .stderr(), "mv: target is not a directory\n");
        std.process.exit(1);
    }

    const cwd = Io.Dir.cwd();
    for (sources) |src| {
        var dest_buf: [Io.Dir.max_path_bytes]u8 = undefined;
        const dest_path: []const u8 = if (dest_is_dir) blk: {
            const base = util.basename(src);
            break :blk try std.fmt.bufPrint(&dest_buf, "{s}/{s}", .{ dest, base });
        } else dest;

        cwd.rename(src, cwd, dest_path, io) catch |err| {
            var buf: [512]u8 = undefined;
            const msg = try std.fmt.bufPrint(&buf, "mv: {s}: {s}\n", .{ src, @errorName(err) });
            try util.writeAll(io, .stderr(), msg);
            std.process.exit(1);
        };
    }
}
