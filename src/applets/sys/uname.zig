const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const posix = std.posix;
const util = @import("util");

pub fn cmdUname(io: Io, args: []const [:0]const u8) !void {
    var print_s = false;
    var print_n = false;
    var print_r = false;
    var print_v = false;
    var print_m = false;
    var print_all = false;
    var any = false;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const a = args[i];
        if (a.len > 0 and a[0] == '-') {
            for (a[1..]) |c| {
                switch (c) {
                    's' => {
                        print_s = true;
                        any = true;
                    },
                    'n' => {
                        print_n = true;
                        any = true;
                    },
                    'r' => {
                        print_r = true;
                        any = true;
                    },
                    'v' => {
                        print_v = true;
                        any = true;
                    },
                    'm' => {
                        print_m = true;
                        any = true;
                    },
                    'a' => {
                        print_all = true;
                        any = true;
                    },
                    else => {},
                }
            }
        }
    }
    if (!any) print_s = true;
    if (print_all) {
        print_s = true;
        print_n = true;
        print_r = true;
        print_v = true;
        print_m = true;
    }

    const uts = posix.uname();
    var wbuf: [512]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const w = &writer.interface;

    var first = true;
    const fields = [_]struct { flag: bool, val: []const u8 }{
        .{ .flag = print_s, .val = mem.sliceTo(&uts.sysname, 0) },
        .{ .flag = print_n, .val = mem.sliceTo(&uts.nodename, 0) },
        .{ .flag = print_r, .val = mem.sliceTo(&uts.release, 0) },
        .{ .flag = print_v, .val = mem.sliceTo(&uts.version, 0) },
        .{ .flag = print_m, .val = mem.sliceTo(&uts.machine, 0) },
    };
    for (fields) |f| {
        if (!f.flag) continue;
        if (!first) try w.writeAll(" ");
        try w.writeAll(f.val);
        first = false;
    }
    try w.writeAll("\n");
    try w.flush();
}
