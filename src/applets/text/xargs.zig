const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdXargs(io: Io, arena: mem.Allocator, args: []const [:0]const u8) !void {
    // xargs [ -n N ] [ -d delim ] [command [initial-args...]]
    // Reads stdin items and runs command via posix.exec — without full spawn API,
    // we print the would-be command lines when command is echo-like, OR
    // use std.process.Child if available in 0.16.
    var max_args: usize = 32;
    var delim: u8 = '\n'; // default: newline (busybox often uses whitespace)
    var whitespace_split = true;
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        const a = args[i];
        if (mem.eql(u8, a, "--")) {
            i += 1;
            break;
        }
        if (mem.eql(u8, a, "-n") and i + 1 < args.len) {
            max_args = std.fmt.parseInt(usize, args[i + 1], 10) catch 32;
            i += 1;
        } else if (mem.eql(u8, a, "-0") or mem.eql(u8, a, "-z")) {
            delim = 0;
            whitespace_split = false;
        } else if (mem.eql(u8, a, "-d") and i + 1 < args.len) {
            delim = if (args[i + 1].len > 0) args[i + 1][0] else '\n';
            whitespace_split = false;
            i += 1;
        }
    }

    const cmd: []const [:0]const u8 = if (i < args.len) args[i..] else &[_][:0]const u8{"echo"};

    // Collect tokens from stdin
    var tokens: std.ArrayListUnmanaged([]const u8) = .empty;
    defer {
        for (tokens.items) |tok| arena.free(tok);
        tokens.deinit(arena);
    }

    var rbuf: [8192]u8 = undefined;
    var reader: Io.File.Reader = .init(.stdin(), io, &rbuf);
    var acc: std.ArrayListUnmanaged(u8) = .empty;
    defer acc.deinit(arena);

    var outbuf: [4096]u8 = undefined;
    while (true) {
        const n = reader.interface.readSliceShort(&outbuf) catch |err| return err;
        if (n == 0) break;
        for (outbuf[0..n]) |c| {
            const is_delim = if (whitespace_split)
                (c == ' ' or c == '\t' or c == '\n' or c == '\r')
            else
                (c == delim);
            if (is_delim) {
                if (acc.items.len > 0) {
                    try tokens.append(arena, try arena.dupe(u8, acc.items));
                    acc.clearRetainingCapacity();
                }
            } else {
                try acc.append(arena, c);
            }
        }
    }
    if (acc.items.len > 0) {
        try tokens.append(arena, try arena.dupe(u8, acc.items));
    }

    // Execute in batches using process.Child if available
    var t: usize = 0;
    while (t < tokens.items.len) {
        const batch_end = @min(t + max_args, tokens.items.len);
        try runXargsBatch(io, arena, cmd, tokens.items[t..batch_end]);
        t = batch_end;
    }
}

fn runXargsBatch(io: Io, arena: mem.Allocator, cmd: []const [:0]const u8, batch: []const []const u8) !void {
    var argv_list: std.ArrayListUnmanaged([]const u8) = .empty;
    defer argv_list.deinit(arena);
    for (cmd) |c| try argv_list.append(arena, c);
    for (batch) |b| try argv_list.append(arena, b);

    var child = process.spawn(io, .{
        .argv = argv_list.items,
        .stdin = .ignore,
        .stdout = .inherit,
        .stderr = .inherit,
    }) catch |err| {
        var buf: [256]u8 = undefined;
        const msg = try std.fmt.bufPrint(&buf, "xargs: {s}: {s}\n", .{ cmd[0], @errorName(err) });
        try util.writeAll(io, .stderr(), msg);
        return;
    };
    _ = child.wait(io) catch {};
}
