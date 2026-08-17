const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdSplit(io: Io, args: []const [:0]const u8) !void {
    // split [-l LINES] [-b SIZE] [FILE [PREFIX]]
    // Default: -l 1000, prefix "x"
    var lines_per: ?usize = 1000;
    var bytes_per: ?usize = null;
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        const a = args[i];
        if (mem.eql(u8, a, "-l") and i + 1 < args.len) {
            i += 1;
            lines_per = std.fmt.parseInt(usize, args[i], 10) catch 1000;
            bytes_per = null;
        } else if (mem.eql(u8, a, "-b") and i + 1 < args.len) {
            i += 1;
            bytes_per = parseSplitSize(args[i]) catch {
                try util.writeAll(io, .stderr(), "split: invalid size\n");
                std.process.exit(1);
            };
            lines_per = null;
        }
    }
    const path: []const u8 = if (i < args.len) args[i] else "-";
    if (i < args.len) i += 1;
    const prefix: []const u8 = if (i < args.len) args[i] else "x";

    const file = if (mem.eql(u8, path, "-"))
        Io.File.stdin()
    else
        Io.Dir.cwd().openFile(io, path, .{}) catch |err| {
            var buf: [256]u8 = undefined;
            const msg = try std.fmt.bufPrint(&buf, "split: {s}: {s}\n", .{ path, @errorName(err) });
            try util.writeAll(io, .stderr(), msg);
            std.process.exit(1);
        };
    defer if (!mem.eql(u8, path, "-")) file.close(io);

    var rbuf: [8192]u8 = undefined;
    var reader: Io.File.Reader = .init(file, io, &rbuf);

    var part: usize = 0;
    var cur_lines: usize = 0;
    var cur_bytes: usize = 0;
    var out_file: ?Io.File = null;
    defer if (out_file) |f| f.close(io);

    const openPart = struct {
        fn call(io2: Io, pref: []const u8, p: usize, current: *?Io.File) !void {
            if (current.*) |f| f.close(io2);
            var name_buf: [256]u8 = undefined;
            // xaa, xab, ... classic two-letter suffix after exhausting would need more; keep simple aa-zz then numeric
            const a: u8 = @intCast('a' + (p / 26) % 26);
            const b: u8 = @intCast('a' + (p % 26));
            const name = try std.fmt.bufPrint(&name_buf, "{s}{c}{c}", .{ pref, a, b });
            current.* = try Io.Dir.cwd().createFile(io2, name, .{});
        }
    }.call;

    try openPart(io, prefix, part, &out_file);

    if (bytes_per) |bp| {
        var chunk: [4096]u8 = undefined;
        while (true) {
            const want = @min(chunk.len, bp - cur_bytes);
            const n = reader.interface.readSliceShort(chunk[0..want]) catch break;
            if (n == 0) break;
            var fbuf: [4096]u8 = undefined;
            var fw: Io.File.Writer = .initStreaming(out_file.?, io, &fbuf);
            try fw.interface.writeAll(chunk[0..n]);
            try fw.interface.flush();
            cur_bytes += n;
            if (cur_bytes >= bp) {
                part += 1;
                cur_bytes = 0;
                try openPart(io, prefix, part, &out_file);
            }
        }
    } else {
        const lp = lines_per.?;
        while (true) {
            const line = (reader.interface.takeDelimiter('\n') catch break) orelse break;
            var fbuf: [4096]u8 = undefined;
            var fw: Io.File.Writer = .initStreaming(out_file.?, io, &fbuf);
            try fw.interface.writeAll(line);
            try fw.interface.writeAll("\n");
            try fw.interface.flush();
            cur_lines += 1;
            if (cur_lines >= lp) {
                part += 1;
                cur_lines = 0;
                try openPart(io, prefix, part, &out_file);
            }
        }
    }
}

fn parseSplitSize(s: []const u8) !usize {
    if (s.len == 0) return error.Invalid;
    var end = s.len;
    var mul: usize = 1;
    const last = s[s.len - 1];
    if (last == 'k' or last == 'K') {
        mul = 1024;
        end -= 1;
    } else if (last == 'm' or last == 'M') {
        mul = 1024 * 1024;
        end -= 1;
    } else if (last == 'b') {
        end -= 1;
    }
    return try std.fmt.parseInt(usize, s[0..end], 10) * mul;
}
