const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdBase64(io: Io, args: []const [:0]const u8) !void {
    // base64 [-d] [-w 0] [FILE]
    var decode = false;
    var wrap: usize = 76;
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        const a = args[i];
        if (mem.eql(u8, a, "--")) {
            i += 1;
            break;
        }
        if (mem.eql(u8, a, "-d") or mem.eql(u8, a, "--decode")) {
            decode = true;
        } else if (mem.eql(u8, a, "-w") and i + 1 < args.len) {
            i += 1;
            wrap = std.fmt.parseInt(usize, args[i], 10) catch 76;
        } else if (a.len > 2 and a[0] == '-' and a[1] == 'w') {
            wrap = std.fmt.parseInt(usize, a[2..], 10) catch 76;
        }
    }

    const path: ?[]const u8 = if (i < args.len) args[i] else null;
    const file = if (path) |p|
        if (mem.eql(u8, p, "-"))
            Io.File.stdin()
        else
            Io.Dir.cwd().openFile(io, p, .{}) catch |err| {
                var buf: [256]u8 = undefined;
                const msg = try std.fmt.bufPrint(&buf, "base64: {s}: {s}\n", .{ p, @errorName(err) });
                try util.writeAll(io, .stderr(), msg);
                std.process.exit(1);
            }
    else
        Io.File.stdin();
    defer if (path) |p| {
        if (!mem.eql(u8, p, "-")) file.close(io);
    };

    var rbuf: [8192]u8 = undefined;
    var reader: Io.File.Reader = .init(file, io, &rbuf);

    // Read all input (bounded for simplicity)
    var data: std.ArrayListUnmanaged(u8) = .empty;
    // Use fixed max for stack-friendly approach via arena-less growth on page allocator
    // Prefer reading in chunks into list with a simple allocator from page_allocator
    const gpa = std.heap.page_allocator;
    defer data.deinit(gpa);

    var chunk: [4096]u8 = undefined;
    while (true) {
        const n = reader.interface.readSliceShort(&chunk) catch |err| return err;
        if (n == 0) break;
        try data.appendSlice(gpa, chunk[0..n]);
    }

    var wbuf: [8192]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const w = &writer.interface;

    if (decode) {
        // strip whitespace
        var cleaned: std.ArrayListUnmanaged(u8) = .empty;
        defer cleaned.deinit(gpa);
        for (data.items) |c| {
            if (c != ' ' and c != '\n' and c != '\r' and c != '\t')
                try cleaned.append(gpa, c);
        }
        const max_dec = std.base64.standard.Decoder.calcSizeForSlice(cleaned.items) catch {
            try util.writeAll(io, .stderr(), "base64: invalid input\n");
            std.process.exit(1);
        };
        const out = try gpa.alloc(u8, max_dec);
        defer gpa.free(out);
        std.base64.standard.Decoder.decode(out, cleaned.items) catch {
            try util.writeAll(io, .stderr(), "base64: invalid input\n");
            std.process.exit(1);
        };
        try w.writeAll(out);
    } else {
        const enc_len = std.base64.standard.Encoder.calcSize(data.items.len);
        const out = try gpa.alloc(u8, enc_len);
        defer gpa.free(out);
        const encoded = std.base64.standard.Encoder.encode(out, data.items);
        if (wrap == 0) {
            try w.writeAll(encoded);
            try w.writeAll("\n");
        } else {
            var off: usize = 0;
            while (off < encoded.len) {
                const end = @min(off + wrap, encoded.len);
                try w.writeAll(encoded[off..end]);
                try w.writeAll("\n");
                off = end;
            }
        }
    }
    try w.flush();
}
