const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const posix = std.posix;
const util = @import("util");

pub fn cmdTest(io: Io, args: []const [:0]const u8) !void {
    // POSIX test / [  — subset of expressions
    // Exit 0 if true, 1 if false, 2 on error
    if (args.len < 2) {
        std.process.exit(1);
    }
    // Drop trailing ] when invoked as [
    const end = if (mem.eql(u8, args[args.len - 1], "]")) args.len - 1 else args.len;
    if (end < 2) {
        std.process.exit(1);
    }
    const a = args[1..end];

    const ok = evalTest(io, a) catch {
        std.process.exit(2);
    };
    std.process.exit(if (ok) 0 else 1);
}

fn evalTest(io: Io, a: []const [:0]const u8) !bool {
    if (a.len == 0) return false;

    // Unary: -z / -n STRING
    if (a.len == 1) {
        return a[0].len != 0; // [ STRING ] is true if non-empty
    }

    if (a.len == 2) {
        const op = a[0];
        const arg = a[1];
        if (mem.eql(u8, op, "-z")) return arg.len == 0;
        if (mem.eql(u8, op, "-n")) return arg.len != 0;
        if (mem.eql(u8, op, "-e")) return pathExists(io, arg);
        if (mem.eql(u8, op, "-f")) return pathIsKind(io, arg, .file);
        if (mem.eql(u8, op, "-d")) return pathIsKind(io, arg, .directory);
        if (mem.eql(u8, op, "-L") or mem.eql(u8, op, "-h")) return pathIsKind(io, arg, .sym_link);
        if (mem.eql(u8, op, "-b")) return pathIsKind(io, arg, .block_device);
        if (mem.eql(u8, op, "-c")) return pathIsKind(io, arg, .character_device);
        if (mem.eql(u8, op, "-p")) return pathIsKind(io, arg, .named_pipe);
        if (mem.eql(u8, op, "-S")) return pathIsKind(io, arg, .unix_domain_socket);
        if (mem.eql(u8, op, "-s")) {
            const st = Io.Dir.cwd().statFile(io, arg, .{}) catch return false;
            return st.size > 0;
        }
        if (mem.eql(u8, op, "-r")) {
            Io.Dir.cwd().access(io, arg, .{ .read = true }) catch return false;
            return true;
        }
        if (mem.eql(u8, op, "-w")) {
            Io.Dir.cwd().access(io, arg, .{ .write = true }) catch return false;
            return true;
        }
        if (mem.eql(u8, op, "-x")) {
            Io.Dir.cwd().access(io, arg, .{ .execute = true }) catch return false;
            return true;
        }
        // unknown unary → treat as [ STRING ] style with two tokens? false
        return false;
    }

    if (a.len == 3) {
        const left = a[0];
        const op = a[1];
        const right = a[2];
        // string compares
        if (mem.eql(u8, op, "=") or mem.eql(u8, op, "==")) return mem.eql(u8, left, right);
        if (mem.eql(u8, op, "!=")) return !mem.eql(u8, left, right);
        // integer compares
        if (mem.eql(u8, op, "-eq") or mem.eql(u8, op, "-ne") or mem.eql(u8, op, "-lt") or
            mem.eql(u8, op, "-le") or mem.eql(u8, op, "-gt") or mem.eql(u8, op, "-ge"))
        {
            const l = std.fmt.parseInt(i64, left, 10) catch return false;
            const r = std.fmt.parseInt(i64, right, 10) catch return false;
            if (mem.eql(u8, op, "-eq")) return l == r;
            if (mem.eql(u8, op, "-ne")) return l != r;
            if (mem.eql(u8, op, "-lt")) return l < r;
            if (mem.eql(u8, op, "-le")) return l <= r;
            if (mem.eql(u8, op, "-gt")) return l > r;
            if (mem.eql(u8, op, "-ge")) return l >= r;
        }
        return false;
    }

    // [ ! EXPR ]
    if (a.len >= 2 and mem.eql(u8, a[0], "!")) {
        return !(try evalTest(io, a[1..]));
    }

    return false;
}

fn pathExists(io: Io, path: []const u8) bool {
    Io.Dir.cwd().access(io, path, .{}) catch return false;
    return true;
}

fn pathIsKind(io: Io, path: []const u8, kind: Io.File.Kind) bool {
    // For symlinks, do not follow
    const follow = kind != .sym_link;
    const st = Io.Dir.cwd().statFile(io, path, .{ .follow_symlinks = follow }) catch return false;
    return st.kind == kind;
}
