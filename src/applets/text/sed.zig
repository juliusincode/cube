const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdSed(io: Io, args: []const [:0]const u8) !void {
    // sed [ -n ] 's/pat/repl/[g]' [FILE]...
    // Fixed-string substitute only (no full regex).
    var quiet = false; // -n
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        const a = args[i];
        if (mem.eql(u8, a, "--")) {
            i += 1;
            break;
        }
        for (a[1..]) |c| {
            if (c == 'n') quiet = true;
        }
    }
    if (i >= args.len) {
        try util.writeAll(io, .stderr(), "sed: missing script\n");
        std.process.exit(1);
    }
    const script = args[i];
    i += 1;

    var pat: []const u8 = "";
    var repl: []const u8 = "";
    var global = false;
    if (!parseSedSubstitute(script, &pat, &repl, &global)) {
        try util.writeAll(io, .stderr(), "sed: unsupported script (only s/// supported)\n");
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
                const msg = try std.fmt.bufPrint(&buf, "sed: {s}: {s}\n", .{ path, @errorName(err) });
                try util.writeAll(io, .stderr(), msg);
                continue;
            };
        defer if (!mem.eql(u8, path, "-")) file.close(io);

        var rbuf: [8192]u8 = undefined;
        var reader: Io.File.Reader = .init(file, io, &rbuf);
        while (true) {
            const line = (reader.interface.takeDelimiter('\n') catch |err| return err) orelse break;
            var out_buf: [16384]u8 = undefined;
            const out = sedReplace(line, pat, repl, global, &out_buf) catch line;
            if (!quiet) {
                try w.writeAll(out);
                try w.writeAll("\n");
            }
        }
    }
    try w.flush();
}

fn parseSedSubstitute(script: []const u8, pat: *[]const u8, repl: *[]const u8, global: *bool) bool {
    // Accept s/pat/repl/ or s/pat/repl/g  (delimiter is first char after s)
    if (script.len < 4 or script[0] != 's') return false;
    const delim = script[1];
    const rest = script[2..];
    const end_pat = mem.indexOfScalar(u8, rest, delim) orelse return false;
    pat.* = rest[0..end_pat];
    const after_pat = rest[end_pat + 1 ..];
    const end_repl = mem.indexOfScalar(u8, after_pat, delim) orelse return false;
    repl.* = after_pat[0..end_repl];
    const flags = after_pat[end_repl + 1 ..];
    global.* = mem.indexOfScalar(u8, flags, 'g') != null;
    return true;
}

test "parseSedSubstitute" {
    var pat: []const u8 = undefined;
    var repl: []const u8 = undefined;
    var g: bool = false;
    try std.testing.expect(parseSedSubstitute("s/foo/bar/", &pat, &repl, &g));
    try std.testing.expectEqualStrings("foo", pat);
    try std.testing.expectEqualStrings("bar", repl);
    try std.testing.expect(!g);
    try std.testing.expect(parseSedSubstitute("s|a|b|g", &pat, &repl, &g));
    try std.testing.expectEqualStrings("a", pat);
    try std.testing.expectEqualStrings("b", repl);
    try std.testing.expect(g);
}

fn sedReplace(line: []const u8, pat: []const u8, repl: []const u8, global: bool, out: []u8) ![]const u8 {
    if (pat.len == 0) {
        if (line.len + repl.len > out.len) return error.NoSpace;
        @memcpy(out[0..line.len], line);
        return out[0..line.len];
    }
    var o: usize = 0;
    var i: usize = 0;
    var replaced_once = false;
    while (i < line.len) {
        if ((!replaced_once or global) and i + pat.len <= line.len and mem.eql(u8, line[i .. i + pat.len], pat)) {
            if (o + repl.len > out.len) return error.NoSpace;
            @memcpy(out[o .. o + repl.len], repl);
            o += repl.len;
            i += pat.len;
            replaced_once = true;
            if (!global) {
                // copy rest
                const rest = line[i..];
                if (o + rest.len > out.len) return error.NoSpace;
                @memcpy(out[o .. o + rest.len], rest);
                o += rest.len;
                break;
            }
        } else {
            if (o + 1 > out.len) return error.NoSpace;
            out[o] = line[i];
            o += 1;
            i += 1;
        }
    }
    return out[0..o];
}

test "sedReplace once and global" {
    var buf: [128]u8 = undefined;
    const a = try sedReplace("foo foo", "foo", "x", false, &buf);
    try std.testing.expectEqualStrings("x foo", a);
    const b = try sedReplace("foo foo", "foo", "x", true, &buf);
    try std.testing.expectEqualStrings("x x", b);
}
