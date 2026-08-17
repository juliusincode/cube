const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdFind(io: Io, arena: mem.Allocator, args: []const [:0]const u8) !void {
    // find [PATH...] [EXPRESSION]
    // Supported: -name PATTERN, -type f|d|l, -maxdepth N
    // Default path: .
    var paths: std.ArrayListUnmanaged([]const u8) = .empty;
    defer paths.deinit(arena);

    var name_pat: ?[]const u8 = null;
    var name_icase = false;
    var path_pat: ?[]const u8 = null;
    var type_filter: ?u8 = null; // 'f', 'd', 'l'
    var maxdepth: ?usize = null;

    var i: usize = 1;
    // Collect leading paths (not starting with -)
    while (i < args.len and args[i].len > 0 and args[i][0] != '-') : (i += 1) {
        try paths.append(arena, args[i]);
    }
    // Parse expression
    while (i < args.len) : (i += 1) {
        const a = args[i];
        if (mem.eql(u8, a, "-name") and i + 1 < args.len) {
            i += 1;
            name_pat = args[i];
            name_icase = false;
        } else if (mem.eql(u8, a, "-iname") and i + 1 < args.len) {
            i += 1;
            name_pat = args[i];
            name_icase = true;
        } else if (mem.eql(u8, a, "-path") and i + 1 < args.len) {
            i += 1;
            path_pat = args[i];
        } else if (mem.eql(u8, a, "-type") and i + 1 < args.len) {
            i += 1;
            if (args[i].len > 0) type_filter = args[i][0];
        } else if (mem.eql(u8, a, "-maxdepth") and i + 1 < args.len) {
            i += 1;
            maxdepth = std.fmt.parseInt(usize, args[i], 10) catch null;
        } else if (a[0] != '-') {
            try paths.append(arena, a);
        }
    }

    if (paths.items.len == 0) {
        try paths.append(arena, ".");
    }

    var wbuf: [8192]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const w = &writer.interface;

    const opts = FindOpts{
        .name_pat = name_pat,
        .name_icase = name_icase,
        .path_pat = path_pat,
        .type_filter = type_filter,
        .maxdepth = maxdepth,
    };

    for (paths.items) |root| {
        try findWalk(io, arena, w, root, 0, opts);
    }
    try w.flush();
}

const FindOpts = struct {
    name_pat: ?[]const u8,
    name_icase: bool = false,
    path_pat: ?[]const u8 = null,
    type_filter: ?u8,
    maxdepth: ?usize,
};

fn findWalk(
    io: Io,
    arena: mem.Allocator,
    w: anytype,
    path: []const u8,
    depth: usize,
    opts: FindOpts,
) anyerror!void {
    // Do not follow symlinks so -type l works
    const st = Io.Dir.cwd().statFile(io, path, .{ .follow_symlinks = false }) catch |err| {
        var buf: [512]u8 = undefined;
        const msg = try std.fmt.bufPrint(&buf, "find: {s}: {s}\n", .{ path, @errorName(err) });
        try util.writeAll(io, .stderr(), msg);
        return;
    };

    if (findMatch(path, util.basename(path), st.kind, opts)) {
        try w.writeAll(path);
        try w.writeAll("\n");
    }

    // Do not descend into symlinked directories
    if (st.kind != .directory) return;
    if (opts.maxdepth) |md| {
        if (depth >= md) return;
    }

    var dir = Io.Dir.cwd().openDir(io, path, .{ .iterate = true }) catch |err| {
        var buf: [512]u8 = undefined;
        const msg = try std.fmt.bufPrint(&buf, "find: {s}: {s}\n", .{ path, @errorName(err) });
        try util.writeAll(io, .stderr(), msg);
        return;
    };
    defer dir.close(io);

    var it = dir.iterate();
    while (try it.next(io)) |entry| {
        if (mem.eql(u8, entry.name, ".") or mem.eql(u8, entry.name, "..")) continue;
        const child = if (path.len == 0 or mem.eql(u8, path, "."))
            try std.fmt.allocPrint(arena, "./{s}", .{entry.name})
        else if (path[path.len - 1] == '/')
            try std.fmt.allocPrint(arena, "{s}{s}", .{ path, entry.name })
        else
            try std.fmt.allocPrint(arena, "{s}/{s}", .{ path, entry.name });
        defer arena.free(child);
        try findWalk(io, arena, w, child, depth + 1, opts);
    }
}

fn findMatch(full_path: []const u8, name: []const u8, kind: Io.File.Kind, opts: FindOpts) bool {
    if (opts.type_filter) |tf| {
        const ok = switch (tf) {
            'f' => kind == .file,
            'd' => kind == .directory,
            'l' => kind == .sym_link,
            'b' => kind == .block_device,
            'c' => kind == .character_device,
            'p' => kind == .named_pipe,
            's' => kind == .unix_domain_socket,
            else => true,
        };
        if (!ok) return false;
    }
    if (opts.name_pat) |pat| {
        if (opts.name_icase) {
            if (!globMatchIgnoreCase(pat, name)) return false;
        } else if (!globMatch(pat, name)) return false;
    }
    if (opts.path_pat) |pat| {
        if (!globMatch(pat, full_path)) return false;
    }
    return true;
}

fn globMatchIgnoreCase(pattern: []const u8, text: []const u8) bool {
    // Lowercase ASCII copies on stack for modest lengths
    var pb: [512]u8 = undefined;
    var tb: [512]u8 = undefined;
    if (pattern.len > pb.len or text.len > tb.len) return globMatch(pattern, text);
    for (pattern, 0..) |c, j| {
        pb[j] = if (c >= 'A' and c <= 'Z') c + 32 else c;
    }
    for (text, 0..) |c, j| {
        tb[j] = if (c >= 'A' and c <= 'Z') c + 32 else c;
    }
    return globMatch(pb[0..pattern.len], tb[0..text.len]);
}

fn globMatch(pattern: []const u8, text: []const u8) bool {
    return globMatchInner(pattern, text);
}

test "globMatch exact" {
    try std.testing.expect(globMatch("file.txt", "file.txt"));
    try std.testing.expect(!globMatch("file.txt", "file.tx"));
}

test "globMatch star" {
    try std.testing.expect(globMatch("*.txt", "file.txt"));
    try std.testing.expect(globMatch("file.*", "file.txt"));
    try std.testing.expect(globMatch("*", "anything"));
    try std.testing.expect(!globMatch("*.txt", "file.log"));
    try std.testing.expect(globMatch("pre*suf", "preXXXsuf"));
}

test "globMatch question" {
    try std.testing.expect(globMatch("a?c", "abc"));
    try std.testing.expect(!globMatch("a?c", "ac"));
    try std.testing.expect(globMatch("??", "ab"));
}

fn globMatchInner(pattern: []const u8, text: []const u8) bool {
    var pi: usize = 0;
    var ti: usize = 0;
    var star_p: ?usize = null;
    var star_t: usize = 0;

    while (ti < text.len) {
        if (pi < pattern.len and (pattern[pi] == text[ti] or pattern[pi] == '?')) {
            pi += 1;
            ti += 1;
        } else if (pi < pattern.len and pattern[pi] == '*') {
            star_p = pi;
            star_t = ti;
            pi += 1;
        } else if (star_p) |sp| {
            pi = sp + 1;
            star_t += 1;
            ti = star_t;
        } else {
            return false;
        }
    }
    while (pi < pattern.len and pattern[pi] == '*') : (pi += 1) {}
    return pi == pattern.len;
}
