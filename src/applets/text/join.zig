const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");
const common = @import("common.zig");

pub fn cmdJoin(io: Io, arena: mem.Allocator, args: []const [:0]const u8) !void {
    // join [-t CHAR] FILE1 FILE2  — join on first field (sorted inputs assumed)
    var delim: u8 = ' ';
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        const a = args[i];
        if (mem.eql(u8, a, "-t") and i + 1 < args.len) {
            i += 1;
            if (args[i].len > 0) delim = args[i][0];
        }
    }
    if (i + 1 >= args.len) {
        try util.writeAll(io, .stderr(), "join: need two files\n");
        std.process.exit(1);
    }
    const path1 = args[i];
    const path2 = args[i + 1];

    const lines1 = try common.readAllLines(io, arena, path1);
    defer common.freeLines(arena, lines1);
    const lines2 = try common.readAllLines(io, arena, path2);
    defer common.freeLines(arena, lines2);

    var wbuf: [8192]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const w = &writer.interface;

    var idx1: usize = 0;
    var idx2: usize = 0;
    while (idx1 < lines1.len and idx2 < lines2.len) {
        const k1 = firstField(lines1[idx1], delim);
        const k2 = firstField(lines2[idx2], delim);
        const ord = mem.order(u8, k1, k2);
        if (ord == .lt) {
            idx1 += 1;
        } else if (ord == .gt) {
            idx2 += 1;
        } else {
            // equal keys: output key + rest of both
            try w.writeAll(k1);
            const r1 = restFields(lines1[idx1], delim);
            const r2 = restFields(lines2[idx2], delim);
            if (r1.len > 0) {
                try w.writeAll(&.{delim});
                try w.writeAll(r1);
            }
            if (r2.len > 0) {
                try w.writeAll(&.{delim});
                try w.writeAll(r2);
            }
            try w.writeAll("\n");
            idx1 += 1;
            idx2 += 1;
        }
    }
    try w.flush();
}

fn firstField(line: []const u8, delim: u8) []const u8 {
    if (mem.indexOfScalar(u8, line, delim)) |p| return line[0..p];
    return line;
}

fn restFields(line: []const u8, delim: u8) []const u8 {
    if (mem.indexOfScalar(u8, line, delim)) |p| {
        if (p + 1 < line.len) return line[p + 1 ..];
        return "";
    }
    return "";
}
