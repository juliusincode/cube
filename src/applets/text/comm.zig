const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");
const common = @import("common.zig");

pub fn cmdComm(io: Io, arena: mem.Allocator, args: []const [:0]const u8) !void {
    // comm [-123] FILE1 FILE2  — compare sorted files line by line
    var show1 = true;
    var show2 = true;
    var show3 = true;
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        for (args[i][1..]) |c| {
            switch (c) {
                '1' => show1 = false,
                '2' => show2 = false,
                '3' => show3 = false,
                else => {},
            }
        }
    }
    if (i + 1 >= args.len) {
        try util.writeAll(io, .stderr(), "comm: need two files\n");
        std.process.exit(1);
    }
    const lines1 = try common.readAllLines(io, arena, args[i]);
    defer common.freeLines(arena, lines1);
    const lines2 = try common.readAllLines(io, arena, args[i + 1]);
    defer common.freeLines(arena, lines2);

    var wbuf: [8192]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const w = &writer.interface;

    var idx1: usize = 0;
    var idx2: usize = 0;
    while (idx1 < lines1.len or idx2 < lines2.len) {
        if (idx1 >= lines1.len) {
            if (show2) {
                if (show1) try w.writeAll("\t");
                try w.writeAll(lines2[idx2]);
                try w.writeAll("\n");
            }
            idx2 += 1;
            continue;
        }
        if (idx2 >= lines2.len) {
            if (show1) {
                try w.writeAll(lines1[idx1]);
                try w.writeAll("\n");
            }
            idx1 += 1;
            continue;
        }
        const ord = mem.order(u8, lines1[idx1], lines2[idx2]);
        if (ord == .lt) {
            if (show1) {
                try w.writeAll(lines1[idx1]);
                try w.writeAll("\n");
            }
            idx1 += 1;
        } else if (ord == .gt) {
            if (show2) {
                if (show1) try w.writeAll("\t");
                try w.writeAll(lines2[idx2]);
                try w.writeAll("\n");
            }
            idx2 += 1;
        } else {
            if (show3) {
                if (show1) try w.writeAll("\t");
                if (show2) try w.writeAll("\t");
                try w.writeAll(lines1[idx1]);
                try w.writeAll("\n");
            }
            idx1 += 1;
            idx2 += 1;
        }
    }
    try w.flush();
}
