const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdGrep(io: Io, arena: mem.Allocator, args: []const [:0]const u8) !void {
    // Fixed-string grep (like grep -F) with common flags:
    //   -i ignore case
    //   -v invert match
    //   -n line numbers
    //   -r/-R recursive directories
    //   -l files with matches only
    //   -c count matches per file
    //   -q quiet (exit status only)
    //   -H / -h force/suppress filename prefix
    var ignore_case = false;
    var invert = false;
    var line_num = false;
    var recursive = false;
    var files_with_matches = false;
    var count_only = false;
    var quiet = false;
    var show_filename: ?bool = null; // null = auto

    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        const a = args[i];
        if (mem.eql(u8, a, "--")) {
            i += 1;
            break;
        }
        if (mem.eql(u8, a, "--help")) {
            try util.writeAll(io, .stdout(),
                \\Usage: grep [-ivnrlcqHh] PATTERN [FILE]...
                \\  -i  ignore case
                \\  -v  invert match
                \\  -n  print line number
                \\  -r  recursive
                \\  -l  print only file names with matches
                \\  -c  print count of matching lines
                \\  -q  quiet; exit status only
                \\  -H  always print filename
                \\  -h  never print filename
                \\
                \\Fixed-string matching (substring), not full regex.
                \\
            );
            return;
        }
        for (a[1..]) |c| {
            switch (c) {
                'i' => ignore_case = true,
                'v' => invert = true,
                'n' => line_num = true,
                'r', 'R' => recursive = true,
                'l' => files_with_matches = true,
                'c' => count_only = true,
                'q' => quiet = true,
                'H' => show_filename = true,
                'h' => show_filename = false,
                'F', 'e' => {}, // fixed string / pattern already default
                else => {},
            }
        }
    }

    if (i >= args.len) {
        try util.writeAll(io, .stderr(), "grep: missing pattern\n");
        std.process.exit(2);
    }
    const pattern = args[i];
    i += 1;

    const files: []const [:0]const u8 = if (i >= args.len)
        &[_][:0]const u8{"-"} // stdin
    else
        args[i..];

    const multi = files.len > 1 or recursive;
    const prefix = show_filename orelse multi;

    var any_match = false;
    var had_error = false;

    for (files) |path| {
        if (mem.eql(u8, path, "-")) {
            const m = try grepFile(io, arena, .stdin(), null, pattern, .{
                .ignore_case = ignore_case,
                .invert = invert,
                .line_num = line_num,
                .files_with_matches = files_with_matches,
                .count_only = count_only,
                .quiet = quiet,
                .show_filename = false,
            });
            if (m) any_match = true;
            continue;
        }

        const st = Io.Dir.cwd().statFile(io, path, .{}) catch |err| {
            if (!quiet) {
                var buf: [512]u8 = undefined;
                const msg = try std.fmt.bufPrint(&buf, "grep: {s}: {s}\n", .{ path, @errorName(err) });
                try util.writeAll(io, .stderr(), msg);
            }
            had_error = true;
            continue;
        };

        if (st.kind == .directory) {
            if (!recursive) {
                if (!quiet) {
                    var buf: [512]u8 = undefined;
                    const msg = try std.fmt.bufPrint(&buf, "grep: {s}: Is a directory\n", .{path});
                    try util.writeAll(io, .stderr(), msg);
                }
                had_error = true;
                continue;
            }
            const m = try grepDir(io, arena, path, pattern, .{
                .ignore_case = ignore_case,
                .invert = invert,
                .line_num = line_num,
                .files_with_matches = files_with_matches,
                .count_only = count_only,
                .quiet = quiet,
                .show_filename = true,
            });
            if (m) any_match = true;
            continue;
        }

        const file = Io.Dir.cwd().openFile(io, path, .{}) catch |err| {
            if (!quiet) {
                var buf: [512]u8 = undefined;
                const msg = try std.fmt.bufPrint(&buf, "grep: {s}: {s}\n", .{ path, @errorName(err) });
                try util.writeAll(io, .stderr(), msg);
            }
            had_error = true;
            continue;
        };
        defer file.close(io);

        const m = try grepFile(io, arena, file, path, pattern, .{
            .ignore_case = ignore_case,
            .invert = invert,
            .line_num = line_num,
            .files_with_matches = files_with_matches,
            .count_only = count_only,
            .quiet = quiet,
            .show_filename = prefix,
        });
        if (m) any_match = true;
    }

    if (had_error and !any_match) std.process.exit(2);
    if (!any_match) std.process.exit(1);
}

const GrepOpts = struct {
    ignore_case: bool,
    invert: bool,
    line_num: bool,
    files_with_matches: bool,
    count_only: bool,
    quiet: bool,
    show_filename: bool,
};

fn grepDir(io: Io, arena: mem.Allocator, dir_path: []const u8, pattern: []const u8, opts: GrepOpts) anyerror!bool {
    var dir = Io.Dir.cwd().openDir(io, dir_path, .{ .iterate = true }) catch return false;
    defer dir.close(io);

    var any = false;
    var it = dir.iterate();
    while (try it.next(io)) |entry| {
        if (mem.eql(u8, entry.name, ".") or mem.eql(u8, entry.name, "..")) continue;
        const child = try std.fmt.allocPrint(arena, "{s}/{s}", .{ dir_path, entry.name });
        defer arena.free(child);

        if (entry.kind == .directory) {
            if (try grepDir(io, arena, child, pattern, opts)) any = true;
            continue;
        }
        if (entry.kind != .file and entry.kind != .sym_link) continue;

        const file = Io.Dir.cwd().openFile(io, child, .{}) catch continue;
        defer file.close(io);
        if (try grepFile(io, arena, file, child, pattern, opts)) any = true;
    }
    return any;
}

fn grepFile(
    io: Io,
    arena: mem.Allocator,
    file: Io.File,
    path: ?[]const u8,
    pattern: []const u8,
    opts: GrepOpts,
) !bool {
    _ = arena;
    var rbuf: [8192]u8 = undefined;
    var reader: Io.File.Reader = .init(file, io, &rbuf);

    var wbuf: [8192]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const w = &writer.interface;

    var line_no: usize = 0;
    var match_count: usize = 0;
    var any = false;

    while (true) {
        const line = (reader.interface.takeDelimiter('\n') catch |err| return err) orelse break;
        line_no += 1;

        const matched = lineMatches(line, pattern, opts.ignore_case);
        const selected = if (opts.invert) !matched else matched;
        if (!selected) continue;

        any = true;
        match_count += 1;

        if (opts.quiet) continue;
        if (opts.files_with_matches) {
            // print once later
            continue;
        }
        if (opts.count_only) continue;

        if (opts.show_filename) {
            if (path) |p| {
                try w.writeAll(p);
                try w.writeAll(":");
            }
        }
        if (opts.line_num) {
            try w.print("{d}:", .{line_no});
        }
        try w.writeAll(line);
        try w.writeAll("\n");
    }

    if (opts.quiet) {
        return any;
    }
    if (opts.files_with_matches) {
        if (any) {
            if (path) |p| {
                try w.writeAll(p);
                try w.writeAll("\n");
            }
        }
        try w.flush();
        return any;
    }
    if (opts.count_only) {
        if (opts.show_filename) {
            if (path) |p| {
                try w.writeAll(p);
                try w.writeAll(":");
            }
        }
        try w.print("{d}\n", .{match_count});
        try w.flush();
        return any;
    }
    try w.flush();
    return any;
}

fn lineMatches(line: []const u8, pattern: []const u8, ignore_case: bool) bool {
    if (pattern.len == 0) return true;
    if (!ignore_case) {
        return mem.indexOf(u8, line, pattern) != null;
    }
    // case-insensitive substring search
    if (pattern.len > line.len) return false;
    var i: usize = 0;
    while (i + pattern.len <= line.len) : (i += 1) {
        if (eqlIgnoreCase(line[i .. i + pattern.len], pattern)) return true;
    }
    return false;
}

test "lineMatches case sensitive" {
    try std.testing.expect(lineMatches("hello world", "world", false));
    try std.testing.expect(lineMatches("hello world", "hello", false));
    try std.testing.expect(!lineMatches("hello world", "WORLD", false));
    try std.testing.expect(!lineMatches("hello", "hello!", false));
    try std.testing.expect(lineMatches("anything", "", false));
}

test "lineMatches case insensitive" {
    try std.testing.expect(lineMatches("Hello World", "world", true));
    try std.testing.expect(lineMatches("Hello World", "HELLO", true));
    try std.testing.expect(lineMatches("FOO", "foo", true));
    try std.testing.expect(!lineMatches("foo", "bar", true));
    try std.testing.expect(!lineMatches("fo", "foo", true));
}

fn eqlIgnoreCase(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |x, y| {
        if (std.ascii.toLower(x) != std.ascii.toLower(y)) return false;
    }
    return true;
}

test "eqlIgnoreCase" {
    try std.testing.expect(eqlIgnoreCase("abc", "ABC"));
    try std.testing.expect(eqlIgnoreCase("AbC", "aBc"));
    try std.testing.expect(!eqlIgnoreCase("abc", "abd"));
    try std.testing.expect(!eqlIgnoreCase("abc", "ab"));
    try std.testing.expect(eqlIgnoreCase("", ""));
}
