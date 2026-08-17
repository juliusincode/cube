const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdDd(io: Io, args: []const [:0]const u8) !void {
    // dd [if=FILE] [of=FILE] [bs=N] [count=N] [skip=N] [seek=N]
    var if_path: ?[]const u8 = null;
    var of_path: ?[]const u8 = null;
    var bs: usize = 512;
    var count: ?usize = null;
    var skip_blocks: usize = 0;
    var seek_blocks: usize = 0;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const a = args[i];
        if (mem.startsWith(u8, a, "if=")) {
            if_path = a[3..];
        } else if (mem.startsWith(u8, a, "of=")) {
            of_path = a[3..];
        } else if (mem.startsWith(u8, a, "bs=")) {
            bs = parseDdSize(a[3..]) catch 512;
        } else if (mem.startsWith(u8, a, "count=")) {
            count = std.fmt.parseInt(usize, a[6..], 10) catch null;
        } else if (mem.startsWith(u8, a, "skip=")) {
            skip_blocks = std.fmt.parseInt(usize, a[5..], 10) catch 0;
        } else if (mem.startsWith(u8, a, "seek=")) {
            seek_blocks = std.fmt.parseInt(usize, a[5..], 10) catch 0;
        }
    }
    if (bs == 0) bs = 512;

    const in_file = if (if_path) |p|
        if (mem.eql(u8, p, "-"))
            Io.File.stdin()
        else
            Io.Dir.cwd().openFile(io, p, .{}) catch |err| {
                var buf: [256]u8 = undefined;
                const msg = try std.fmt.bufPrint(&buf, "dd: {s}: {s}\n", .{ p, @errorName(err) });
                try util.writeAll(io, .stderr(), msg);
                std.process.exit(1);
            }
    else
        Io.File.stdin();
    defer if (if_path) |p| {
        if (!mem.eql(u8, p, "-")) in_file.close(io);
    };

    const out_file = if (of_path) |p|
        if (mem.eql(u8, p, "-"))
            Io.File.stdout()
        else
            Io.Dir.cwd().createFile(io, p, .{}) catch |err| {
                var buf: [256]u8 = undefined;
                const msg = try std.fmt.bufPrint(&buf, "dd: {s}: {s}\n", .{ p, @errorName(err) });
                try util.writeAll(io, .stderr(), msg);
                std.process.exit(1);
            }
    else
        Io.File.stdout();
    defer if (of_path) |p| {
        if (!mem.eql(u8, p, "-")) out_file.close(io);
    };

    // skip input blocks
    var skip_left = skip_blocks * bs;
    var discard: [4096]u8 = undefined;
    while (skip_left > 0) {
        const n = @min(skip_left, discard.len);
        const got = blk: {
            var rbuf: [4096]u8 = undefined;
            var reader: Io.File.Reader = .init(in_file, io, &rbuf);
            break :blk reader.interface.readSliceShort(discard[0..n]) catch 0;
        };
        if (got == 0) break;
        skip_left -|= got;
    }

    // seek on output via positional writes
    var out_off: u64 = @as(u64, @intCast(seek_blocks)) *% @as(u64, @intCast(bs));
    const use_positional = (of_path != null and !mem.eql(u8, of_path.?, "-") and seek_blocks > 0);

    var records_in: usize = 0;
    var records_out: usize = 0;
    var bytes_out: u64 = 0;
    var blocks_done: usize = 0;

    const gpa = std.heap.page_allocator;
    const block = try gpa.alloc(u8, bs);
    defer gpa.free(block);

    while (true) {
        if (count) |c| {
            if (blocks_done >= c) break;
        }
        var rbuf: [8192]u8 = undefined;
        var reader: Io.File.Reader = .init(in_file, io, &rbuf);
        // read up to bs bytes
        var got: usize = 0;
        while (got < bs) {
            const n = reader.interface.readSliceShort(block[got..]) catch break;
            if (n == 0) break;
            got += n;
        }
        if (got == 0) break;
        records_in += 1;
        blocks_done += 1;

        if (use_positional) {
            out_file.writePositionalAll(io, block[0..got], out_off) catch {};
            out_off += got;
        } else {
            var wbuf: [8192]u8 = undefined;
            var writer: Io.File.Writer = .initStreaming(out_file, io, &wbuf);
            writer.interface.writeAll(block[0..got]) catch {};
            writer.interface.flush() catch {};
        }
        records_out += 1;
        bytes_out += got;
        if (got < bs) break; // partial last block
    }

    // status to stderr
    var sbuf: [128]u8 = undefined;
    const status = try std.fmt.bufPrint(&sbuf, "{d}+0 records in\n{d}+0 records out\n{d} bytes copied\n", .{
        records_in, records_out, bytes_out,
    });
    try util.writeAll(io, .stderr(), status);
}

fn parseDdSize(s: []const u8) !usize {
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
        mul = 512;
        end -= 1;
    }
    return try std.fmt.parseInt(usize, s[0..end], 10) * mul;
}
