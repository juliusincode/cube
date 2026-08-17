const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdStat(io: Io, args: []const [:0]const u8) !void {
    // stat [FILE]...  — print file status
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        // -c format later
    }
    if (i >= args.len) {
        try util.writeAll(io, .stderr(), "stat: missing operand\n");
        std.process.exit(1);
    }

    var wbuf: [2048]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const w = &writer.interface;

    var failed = false;
    while (i < args.len) : (i += 1) {
        const path = args[i];
        const st = Io.Dir.cwd().statFile(io, path, .{ .follow_symlinks = false }) catch |err| {
            var buf: [256]u8 = undefined;
            const msg = try std.fmt.bufPrint(&buf, "stat: {s}: {s}\n", .{ path, @errorName(err) });
            try util.writeAll(io, .stderr(), msg);
            failed = true;
            continue;
        };
        const mode = st.permissions.toMode();
        const kind_str: []const u8 = switch (st.kind) {
            .file => "regular file",
            .directory => "directory",
            .sym_link => "symbolic link",
            .block_device => "block special file",
            .character_device => "character special file",
            .named_pipe => "fifo",
            .unix_domain_socket => "socket",
            else => "unknown",
        };
        const mtime_s = st.mtime.toSeconds();
        try w.print("  File: {s}\n", .{path});
        try w.print("  Size: {d}\tBlocks: ?\tIO Block: {d}\t{s}\n", .{ st.size, st.block_size, kind_str });
        try w.print("Device: ?\tInode: {d}\tLinks: {d}\n", .{ st.inode, st.nlink });
        try w.print("Access: ({o:0>4}/--------)\tUid: ?\tGid: ?\n", .{mode});
        try w.print("Modify: {d}\n", .{mtime_s});
    }
    try w.flush();
    if (failed) std.process.exit(1);
}
