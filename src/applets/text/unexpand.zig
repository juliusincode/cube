const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdUnexpand(io: Io, args: []const [:0]const u8) !void {
    // unexpand [-t N] [-a] [FILE]...  — spaces to tabs (default only leading)
    var tab: usize = 8;
    var all = false;
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        const a = args[i];
        if (mem.eql(u8, a, "-t") and i + 1 < args.len) {
            i += 1;
            tab = std.fmt.parseInt(usize, args[i], 10) catch 8;
        } else if (a.len > 2 and a[0] == '-' and a[1] == 't') {
            tab = std.fmt.parseInt(usize, a[2..], 10) catch 8;
        } else if (mem.eql(u8, a, "-a") or mem.eql(u8, a, "--all")) {
            all = true;
        }
    }
    if (tab == 0) tab = 8;

    const paths: []const [:0]const u8 = if (i >= args.len)
        &[_][:0]const u8{"-"}
    else
        args[i..];

    var wbuf: [8192]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const w = &writer.interface;

    for (paths) |path| {
        const file = if (mem.eql(u8, path, "-"))
            Io.File.stdin()
        else
            Io.Dir.cwd().openFile(io, path, .{}) catch |err| {
                var buf: [256]u8 = undefined;
                const msg = try std.fmt.bufPrint(&buf, "unexpand: {s}: {s}\n", .{ path, @errorName(err) });
                try util.writeAll(io, .stderr(), msg);
                continue;
            };
        defer if (!mem.eql(u8, path, "-")) file.close(io);

        var rbuf: [8192]u8 = undefined;
        var reader: Io.File.Reader = .init(file, io, &rbuf);
        while (true) {
            const line = (reader.interface.takeDelimiter('\n') catch break) orelse break;
            try unexpandLine(w, line, tab, all);
            try w.writeAll("\n");
        }
    }
    try w.flush();
}

fn unexpandLine(w: anytype, line: []const u8, tab: usize, all: bool) !void {
    var col: usize = 0;
    var space_run: usize = 0;
    var in_leading = true;
    for (line) |c| {
        if (c == ' ') {
            space_run += 1;
            col += 1;
            if (col % tab == 0 and (all or in_leading)) {
                try w.writeAll("\t");
                space_run = 0;
            }
        } else {
            in_leading = false;
            while (space_run > 0) : (space_run -= 1) {
                try w.writeAll(" ");
            }
            try w.writeAll(&.{c});
            if (c == '\t') {
                col = (col / tab + 1) * tab;
            } else {
                col += 1;
            }
        }
    }
    while (space_run > 0) : (space_run -= 1) {
        try w.writeAll(" ");
    }
}
