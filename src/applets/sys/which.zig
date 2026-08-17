const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const posix = std.posix;
const util = @import("util");

pub fn cmdWhich(io: Io, arena: mem.Allocator, args: []const [:0]const u8, environ: *process.Environ.Map) !void {
    if (args.len < 2) {
        try util.writeAll(io, .stderr(), "which: missing operand\n");
        std.process.exit(1);
    }

    const path_env = environ.get("PATH") orelse "/bin:/usr/bin";
    var found_any = false;
    var failed = false;

    var wbuf: [4096]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const w = &writer.interface;

    for (args[1..]) |name| {
        // If name contains '/', check as path
        if (mem.indexOfScalar(u8, name, '/') != null) {
            Io.Dir.cwd().access(io, name, .{ .execute = true }) catch {
                failed = true;
                continue;
            };
            try w.writeAll(name);
            try w.writeAll("\n");
            found_any = true;
            continue;
        }

        var path_iter = mem.splitScalar(u8, path_env, ':');
        var hit = false;
        while (path_iter.next()) |dir| {
            if (dir.len == 0) continue;
            const candidate = try std.fmt.allocPrint(arena, "{s}/{s}", .{ dir, name });
            defer arena.free(candidate);
            Io.Dir.cwd().access(io, candidate, .{ .execute = true }) catch continue;
            try w.writeAll(candidate);
            try w.writeAll("\n");
            hit = true;
            found_any = true;
            break;
        }
        if (!hit) failed = true;
    }
    try w.flush();
    if (failed or !found_any) std.process.exit(1);
}
