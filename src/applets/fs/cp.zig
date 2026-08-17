const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdCp(io: Io, arena: mem.Allocator, args: []const [:0]const u8) !void {
    var recursive = false;
    var i: usize = 1;
    while (i < args.len and args[i].len > 0 and args[i][0] == '-') : (i += 1) {
        const opt = args[i];
        if (mem.eql(u8, opt, "--")) {
            i += 1;
            break;
        }
        if (mem.eql(u8, opt, "-r") or mem.eql(u8, opt, "-R") or mem.eql(u8, opt, "--recursive")) {
            recursive = true;
        } else if (mem.eql(u8, opt, "-rf") or mem.eql(u8, opt, "-fr") or mem.eql(u8, opt, "-Rf") or mem.eql(u8, opt, "-fR")) {
            recursive = true;
        }
        // other flags ignored for now
    }
    if (i + 1 >= args.len) {
        try util.writeAll(io, .stderr(), "cp: missing file operand\n");
        std.process.exit(1);
    }
    // Support: cp [-r] SRC... DEST  — for now require exactly one SRC and DEST
    // when more than two operands and dest is dir, copy each into dest (basic)
    const operands = args[i..];
    if (operands.len < 2) {
        try util.writeAll(io, .stderr(), "cp: missing file operand\n");
        std.process.exit(1);
    }
    const dest = operands[operands.len - 1];
    const sources = operands[0 .. operands.len - 1];

    // Check if dest is an existing directory
    const dest_is_dir = blk: {
        const st = Io.Dir.cwd().statFile(io, dest, .{}) catch break :blk false;
        break :blk st.kind == .directory;
    };

    if (sources.len > 1 and !dest_is_dir) {
        try util.writeAll(io, .stderr(), "cp: target is not a directory\n");
        std.process.exit(1);
    }

    for (sources) |src_path| {
        var dest_path_buf: [Io.Dir.max_path_bytes]u8 = undefined;
        const dest_path: []const u8 = if (dest_is_dir) blk: {
            const base = util.basename(src_path);
            break :blk try std.fmt.bufPrint(&dest_path_buf, "{s}/{s}", .{ dest, base });
        } else dest;

        try copyPath(io, arena, src_path, dest_path, recursive);
    }
}

fn copyPath(io: Io, arena: mem.Allocator, src_path: []const u8, dest_path: []const u8, recursive: bool) anyerror!void {
    const st = Io.Dir.cwd().statFile(io, src_path, .{}) catch |err| {
        var buf: [512]u8 = undefined;
        const msg = try std.fmt.bufPrint(&buf, "cp: {s}: {s}\n", .{ src_path, @errorName(err) });
        try util.writeAll(io, .stderr(), msg);
        return;
    };

    if (st.kind == .directory) {
        if (!recursive) {
            var buf: [512]u8 = undefined;
            const msg = try std.fmt.bufPrint(&buf, "cp: -r not specified; omitting directory '{s}'\n", .{src_path});
            try util.writeAll(io, .stderr(), msg);
            return;
        }
        try copyDirRecursive(io, arena, src_path, dest_path);
        return;
    }

    // regular file (or other)
    const src = Io.Dir.cwd().openFile(io, src_path, .{}) catch |err| {
        var buf: [512]u8 = undefined;
        const msg = try std.fmt.bufPrint(&buf, "cp: {s}: {s}\n", .{ src_path, @errorName(err) });
        try util.writeAll(io, .stderr(), msg);
        return;
    };
    defer src.close(io);
    const dst = Io.Dir.cwd().createFile(io, dest_path, .{}) catch |err| {
        var buf: [512]u8 = undefined;
        const msg = try std.fmt.bufPrint(&buf, "cp: {s}: {s}\n", .{ dest_path, @errorName(err) });
        try util.writeAll(io, .stderr(), msg);
        return;
    };
    defer dst.close(io);
    try util.copyFile(io, src, dst);
}

fn copyDirRecursive(io: Io, arena: mem.Allocator, src_path: []const u8, dest_path: []const u8) anyerror!void {
    Io.Dir.cwd().createDir(io, dest_path, .default_dir) catch |err| {
        // ok if exists
        if (err != error.PathAlreadyExists) {
            var buf: [512]u8 = undefined;
            const msg = try std.fmt.bufPrint(&buf, "cp: {s}: {s}\n", .{ dest_path, @errorName(err) });
            try util.writeAll(io, .stderr(), msg);
            return;
        }
    };

    var dir = Io.Dir.cwd().openDir(io, src_path, .{ .iterate = true }) catch |err| {
        var buf: [512]u8 = undefined;
        const msg = try std.fmt.bufPrint(&buf, "cp: {s}: {s}\n", .{ src_path, @errorName(err) });
        try util.writeAll(io, .stderr(), msg);
        return;
    };
    defer dir.close(io);

    var it = dir.iterate();
    while (try it.next(io)) |entry| {
        if (mem.eql(u8, entry.name, ".") or mem.eql(u8, entry.name, "..")) continue;
        const child_src = try std.fmt.allocPrint(arena, "{s}/{s}", .{ src_path, entry.name });
        defer arena.free(child_src);
        const child_dst = try std.fmt.allocPrint(arena, "{s}/{s}", .{ dest_path, entry.name });
        defer arena.free(child_dst);
        try copyPath(io, arena, child_src, child_dst, true);
    }
}
