const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdCat(io: Io, args: []const [:0]const u8) !void {
    var number = false; // -n number all lines
    var number_nonblank = false; // -b number non-empty lines
    var squeeze = false; // -s squeeze blank lines
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        const a = args[i];
        if (mem.eql(u8, a, "--")) {
            i += 1;
            break;
        }
        if (a.len == 1) break; // "-" means stdin
        for (a[1..]) |c| {
            switch (c) {
                'n' => number = true,
                'b' => {
                    number_nonblank = true;
                    number = true; // -b implies numbering non-blank only
                },
                's' => squeeze = true,
                else => {},
            }
        }
    }

    const files: []const [:0]const u8 = if (i >= args.len)
        &[_][:0]const u8{"-"}
    else
        args[i..];

    var line_no: usize = 1;
    var prev_blank = false;

    for (files) |path| {
        if (mem.eql(u8, path, "-")) {
            try catStream(io, .stdin(), number, number_nonblank, squeeze, &line_no, &prev_blank);
            continue;
        }
        const file = Io.Dir.cwd().openFile(io, path, .{}) catch |err| {
            var ebuf: [512]u8 = undefined;
            const msg = try std.fmt.bufPrint(&ebuf, "cat: {s}: {s}\n", .{ path, @errorName(err) });
            try util.writeAll(io, .stderr(), msg);
            continue;
        };
        defer file.close(io);
        try catStream(io, file, number, number_nonblank, squeeze, &line_no, &prev_blank);
    }
}

fn catStream(
    io: Io,
    file: Io.File,
    number: bool,
    number_nonblank: bool,
    squeeze: bool,
    line_no: *usize,
    prev_blank: *bool,
) !void {
    if (!number and !squeeze) {
        try util.copyFile(io, file, .stdout());
        return;
    }

    var rbuf: [8192]u8 = undefined;
    var reader: Io.File.Reader = .init(file, io, &rbuf);
    var wbuf: [8192]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const w = &writer.interface;

    while (true) {
        const line = (reader.interface.takeDelimiter('\n') catch |err| return err) orelse break;
        const blank = line.len == 0;

        if (squeeze and blank and prev_blank.*) continue;
        prev_blank.* = blank;

        if (number) {
            if (number_nonblank and blank) {
                try w.writeAll("\n");
                continue;
            }
            try w.print("{d: >6}\t", .{line_no.*});
            line_no.* += 1;
        }
        try w.writeAll(line);
        try w.writeAll("\n");
    }
    try w.flush();
}
