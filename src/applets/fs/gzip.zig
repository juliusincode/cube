const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdGzip(io: Io, args: []const [:0]const u8) !void {
    // gzip -d|-c [FILE]...  — decompress only for now (inflate gzip)
    // compress not implemented (keeps binary size down)
    var decompress = false;
    var to_stdout = false;
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        const a = args[i];
        if (mem.eql(u8, a, "-d") or mem.eql(u8, a, "--decompress") or mem.eql(u8, a, "--uncompress")) {
            decompress = true;
        } else if (mem.eql(u8, a, "-c") or mem.eql(u8, a, "--stdout") or mem.eql(u8, a, "--to-stdout")) {
            to_stdout = true;
        } else if (mem.eql(u8, a, "-dc") or mem.eql(u8, a, "-cd")) {
            decompress = true;
            to_stdout = true;
        }
    }
    if (!decompress) {
        // compress files (or stdin)
        if (i >= args.len) {
            try gzipStream(io, Io.File.stdin(), Io.File.stdout());
            return;
        }
        while (i < args.len) : (i += 1) {
            const path = args[i];
            const in_f = Io.Dir.cwd().openFile(io, path, .{}) catch |err| {
                var buf: [256]u8 = undefined;
                const msg = try std.fmt.bufPrint(&buf, "gzip: {s}: {s}\n", .{ path, @errorName(err) });
                try util.writeAll(io, .stderr(), msg);
                continue;
            };
            defer in_f.close(io);
            if (to_stdout) {
                try gzipStream(io, in_f, Io.File.stdout());
            } else {
                var out_name_buf: [Io.Dir.max_path_bytes]u8 = undefined;
                const out_name = try std.fmt.bufPrint(&out_name_buf, "{s}.gz", .{path});
                const out_f = Io.Dir.cwd().createFile(io, out_name, .{}) catch |err| {
                    var buf: [256]u8 = undefined;
                    const msg = try std.fmt.bufPrint(&buf, "gzip: {s}: {s}\n", .{ out_name, @errorName(err) });
                    try util.writeAll(io, .stderr(), msg);
                    continue;
                };
                defer out_f.close(io);
                try gzipStream(io, in_f, out_f);
                Io.Dir.cwd().deleteFile(io, path) catch {};
            }
        }
        return;
    }
    if (i >= args.len) {
        // stdin -> stdout
        try gunzipStream(io, Io.File.stdin(), Io.File.stdout());
        return;
    }
    while (i < args.len) : (i += 1) {
        const path = args[i];
        const in_f = Io.Dir.cwd().openFile(io, path, .{}) catch |err| {
            var buf: [256]u8 = undefined;
            const msg = try std.fmt.bufPrint(&buf, "gzip: {s}: {s}\n", .{ path, @errorName(err) });
            try util.writeAll(io, .stderr(), msg);
            continue;
        };
        defer in_f.close(io);

        if (to_stdout) {
            try gunzipStream(io, in_f, Io.File.stdout());
        } else {
            // strip .gz
            const out_path = if (mem.endsWith(u8, path, ".gz") and path.len > 3)
                path[0 .. path.len - 3]
            else
                path; // write alongside without extension change fallback
            var out_name_buf: [Io.Dir.max_path_bytes]u8 = undefined;
            const out_name = if (mem.endsWith(u8, path, ".gz") and path.len > 3)
                path[0 .. path.len - 3]
            else blk: {
                break :blk try std.fmt.bufPrint(&out_name_buf, "{s}.out", .{path});
            };
            _ = out_path;
            const out_f = Io.Dir.cwd().createFile(io, out_name, .{}) catch |err| {
                var buf: [256]u8 = undefined;
                const msg = try std.fmt.bufPrint(&buf, "gzip: {s}: {s}\n", .{ out_name, @errorName(err) });
                try util.writeAll(io, .stderr(), msg);
                continue;
            };
            defer out_f.close(io);
            try gunzipStream(io, in_f, out_f);
            Io.Dir.cwd().deleteFile(io, path) catch {};
        }
    }
}

fn gzipStream(io: Io, in_file: Io.File, out_file: Io.File) !void {
    const gpa = std.heap.page_allocator;
    const window = try gpa.alloc(u8, std.compress.flate.max_window_len);
    defer gpa.free(window);

    var wbuf: [8192]u8 = undefined;
    const is_stdio = out_file.handle == Io.File.stdout().handle;
    var file_writer: Io.File.Writer = if (is_stdio)
        .initStreaming(out_file, io, &wbuf)
    else
        .init(out_file, io, &wbuf);

    var compress = try std.compress.flate.Compress.init(
        &file_writer.interface,
        window,
        .gzip,
        .default,
    );

    var rbuf: [8192]u8 = undefined;
    var file_reader: Io.File.Reader = .init(in_file, io, &rbuf);
    var chunk: [8192]u8 = undefined;
    while (true) {
        const n = file_reader.interface.readSliceShort(&chunk) catch break;
        if (n == 0) break;
        try compress.writer.writeAll(chunk[0..n]);
    }
    try compress.finish();
    try file_writer.interface.flush();
}

fn gunzipStream(io: Io, in_file: Io.File, out_file: Io.File) !void {
    var rbuf: [std.compress.flate.max_window_len]u8 = undefined;
    var file_reader: Io.File.Reader = .init(in_file, io, &rbuf);
    var dbuf: [std.compress.flate.max_window_len]u8 = undefined;
    var decompress: std.compress.flate.Decompress = .init(&file_reader.interface, .gzip, &dbuf);

    var wbuf: [8192]u8 = undefined;
    const is_stdio = out_file.handle == Io.File.stdout().handle;
    var writer: Io.File.Writer = if (is_stdio)
        .initStreaming(out_file, io, &wbuf)
    else
        .init(out_file, io, &wbuf);

    var out_chunk: [8192]u8 = undefined;
    while (true) {
        const n = decompress.reader.readSliceShort(&out_chunk) catch |err| {
            if (err == error.EndOfStream) break;
            return err;
        };
        if (n == 0) break;
        try writer.interface.writeAll(out_chunk[0..n]);
    }
    try writer.interface.flush();
}
