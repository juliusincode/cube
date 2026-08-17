const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdEcho(io: Io, args: []const [:0]const u8) !void {
    var buf: [4096]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &buf);
    const w = &writer.interface;

    var n_flag = false;
    var interpret_escapes = false; // -e
    var start: usize = 1;
    while (start < args.len and args[start].len > 0 and args[start][0] == '-') : (start += 1) {
        const a = args[start];
        if (mem.eql(u8, a, "--")) {
            start += 1;
            break;
        }
        // lone "-" is an argument, not a flag
        if (a.len == 1) break;
        for (a[1..]) |c| {
            switch (c) {
                'n' => n_flag = true,
                'e' => interpret_escapes = true,
                'E' => interpret_escapes = false,
                else => {},
            }
        }
    }

    var first = true;
    for (args[start..]) |arg| {
        if (!first) try w.writeAll(" ");
        if (interpret_escapes) {
            try writeEchoEscaped(w, arg);
        } else {
            try w.writeAll(arg);
        }
        first = false;
    }
    if (!n_flag) try w.writeAll("\n");
    try w.flush();
}

fn writeEchoEscaped(w: anytype, s: []const u8) !void {
    var i: usize = 0;
    while (i < s.len) {
        if (s[i] == '\\' and i + 1 < s.len) {
            const c = s[i + 1];
            i += 2;
            switch (c) {
                'n' => try w.writeAll("\n"),
                't' => try w.writeAll("\t"),
                'r' => try w.writeAll("\r"),
                '\\' => try w.writeAll("\\"),
                'a' => try w.writeAll("\x07"),
                'b' => try w.writeAll("\x08"),
                'f' => try w.writeAll("\x0c"),
                'v' => try w.writeAll("\x0b"),
                '0' => try w.writeAll(&.{0}),
                'c' => return, // stop output (busybox/bash)
                'x' => {
                    // \xHH
                    if (i + 1 < s.len) {
                        const hi = std.fmt.parseInt(u8, s[i .. i + 1], 16) catch {
                            try w.writeAll(&.{ '\\', 'x' });
                            continue;
                        };
                        if (i + 1 < s.len) {
                            const lo = std.fmt.parseInt(u8, s[i + 1 .. i + 2], 16) catch {
                                try w.writeAll(&.{@as(u8, @intCast(hi))});
                                i += 1;
                                continue;
                            };
                            try w.writeAll(&.{(hi << 4) | lo});
                            i += 2;
                        }
                    } else {
                        try w.writeAll(&.{ '\\', 'x' });
                    }
                },
                else => {
                    try w.writeAll(&.{ '\\', c });
                },
            }
        } else {
            try w.writeAll(s[i .. i + 1]);
            i += 1;
        }
    }
}

test "writeEchoEscaped newlines and tabs" {
    var list: std.ArrayListUnmanaged(u8) = .empty;
    defer list.deinit(std.testing.allocator);
    const W = struct {
        list: *std.ArrayListUnmanaged(u8),
        alloc: std.mem.Allocator,
        pub fn writeAll(self: *@This(), data: []const u8) !void {
            try self.list.appendSlice(self.alloc, data);
        }
    };
    var w: W = .{ .list = &list, .alloc = std.testing.allocator };
    try writeEchoEscaped(&w, "a\\nb\\tc");
    try std.testing.expectEqualStrings("a\nb\tc", list.items);
}

test "writeEchoEscaped stop with c" {
    var list: std.ArrayListUnmanaged(u8) = .empty;
    defer list.deinit(std.testing.allocator);
    const W = struct {
        list: *std.ArrayListUnmanaged(u8),
        alloc: std.mem.Allocator,
        pub fn writeAll(self: *@This(), data: []const u8) !void {
            try self.list.appendSlice(self.alloc, data);
        }
    };
    var w: W = .{ .list = &list, .alloc = std.testing.allocator };
    try writeEchoEscaped(&w, "hi\\cIGNORE");
    try std.testing.expectEqualStrings("hi", list.items);
}
