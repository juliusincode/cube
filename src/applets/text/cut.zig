const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdCut(io: Io, args: []const [:0]const u8) !void {
    var delimiter: u8 = '\t';
    var fields_spec: ?[]const u8 = null;
    var chars_spec: ?[]const u8 = null;
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const a = args[i];
        if (mem.eql(u8, a, "-d") and i + 1 < args.len) {
            delimiter = if (args[i + 1].len > 0) args[i + 1][0] else '\t';
            i += 1;
        } else if (mem.eql(u8, a, "-f") and i + 1 < args.len) {
            fields_spec = args[i + 1];
            i += 1;
        } else if (mem.eql(u8, a, "-c") and i + 1 < args.len) {
            chars_spec = args[i + 1];
            i += 1;
        } else if (a.len > 2 and a[0] == '-' and a[1] == 'd') {
            delimiter = a[2];
        } else if (a.len > 2 and a[0] == '-' and a[1] == 'f') {
            fields_spec = a[2..];
        } else if (a.len > 2 and a[0] == '-' and a[1] == 'c') {
            chars_spec = a[2..];
        } else if (a[0] != '-') {
            break;
        }
    }

    if (fields_spec == null and chars_spec == null) {
        try util.writeAll(io, .stderr(), "cut: you must specify a list of bytes, characters, or fields\n");
        std.process.exit(1);
    }

    const files: []const [:0]const u8 = if (i >= args.len)
        &[_][:0]const u8{"-"}
    else
        args[i..];

    var wbuf: [8192]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const w = &writer.interface;

    for (files) |path| {
        const file = if (mem.eql(u8, path, "-"))
            Io.File.stdin()
        else
            Io.Dir.cwd().openFile(io, path, .{}) catch |err| {
                var buf: [256]u8 = undefined;
                const msg = try std.fmt.bufPrint(&buf, "cut: {s}: {s}\n", .{ path, @errorName(err) });
                try util.writeAll(io, .stderr(), msg);
                continue;
            };
        defer if (!mem.eql(u8, path, "-")) file.close(io);

        var rbuf: [8192]u8 = undefined;
        var reader: Io.File.Reader = .init(file, io, &rbuf);
        while (true) {
            const line = (reader.interface.takeDelimiter('\n') catch |err| return err) orelse break;
            if (chars_spec) |spec| {
                try cutChars(w, line, spec);
            } else if (fields_spec) |spec| {
                try cutFields(w, line, delimiter, spec);
            }
            try w.writeAll("\n");
        }
    }
    try w.flush();
}

fn cutChars(w: anytype, line: []const u8, spec: []const u8) !void {
    var bits: std.StaticBitSet(4096) = .initEmpty();
    // parse into static set
    var it = mem.splitScalar(u8, spec, ',');
    while (it.next()) |part| {
        if (mem.indexOfScalar(u8, part, '-')) |dash| {
            const lo = std.fmt.parseInt(usize, part[0..dash], 10) catch continue;
            const hi_s = part[dash + 1 ..];
            const hi = if (hi_s.len == 0) line.len else std.fmt.parseInt(usize, hi_s, 10) catch continue;
            var n = lo;
            while (n <= hi and n <= line.len) : (n += 1) {
                if (n > 0 and n <= 4095) bits.set(n);
            }
        } else {
            const n = std.fmt.parseInt(usize, part, 10) catch continue;
            if (n > 0 and n <= line.len and n <= 4095) bits.set(n);
        }
    }
    var idx: usize = 1;
    while (idx <= line.len) : (idx += 1) {
        if (bits.isSet(idx)) try w.writeAll(line[idx - 1 .. idx]);
    }
}

test "cutChars range" {
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
    try cutChars(&w, "abcdef", "2-4");
    try std.testing.expectEqualStrings("bcd", list.items);
}

fn cutFields(w: anytype, line: []const u8, delim: u8, spec: []const u8) !void {
    var selected: [256]bool = [_]bool{false} ** 256;
    var it = mem.splitScalar(u8, spec, ',');
    while (it.next()) |part| {
        if (mem.indexOfScalar(u8, part, '-')) |dash| {
            const lo = std.fmt.parseInt(usize, part[0..dash], 10) catch continue;
            const hi_s = part[dash + 1 ..];
            const hi = if (hi_s.len == 0) 255 else std.fmt.parseInt(usize, hi_s, 10) catch continue;
            var n = lo;
            while (n <= hi and n < 256) : (n += 1) {
                if (n > 0) selected[n] = true;
            }
        } else {
            const n = std.fmt.parseInt(usize, part, 10) catch continue;
            if (n > 0 and n < 256) selected[n] = true;
        }
    }

    var field: usize = 1;
    var start: usize = 0;
    var first_out = true;
    var pos: usize = 0;
    while (pos <= line.len) : (pos += 1) {
        const at_end = pos == line.len;
        const is_delim = !at_end and line[pos] == delim;
        if (is_delim or at_end) {
            if (field < 256 and selected[field]) {
                if (!first_out) try w.writeAll(&.{delim});
                try w.writeAll(line[start..pos]);
                first_out = false;
            }
            field += 1;
            start = pos + 1;
            if (at_end) break;
        }
    }
}

test "cutFields extracts selected fields" {
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
    try cutFields(&w, "a:b:c:d", ':', "1,3");
    try std.testing.expectEqualStrings("a:c", list.items);
}

test "cutFields range" {
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
    try cutFields(&w, "a:b:c:d", ':', "2-4");
    try std.testing.expectEqualStrings("b:c:d", list.items);
}
