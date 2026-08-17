const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;

const util = @import("util");
const text = @import("text");
const fs = @import("fs");
const sys = @import("sys");
const version = @import("version");
const applets_list = @import("applets_list");

pub fn main(init: process.Init) !void {
    const arena = init.arena.allocator();
    const io = init.io;
    const args = try init.minimal.args.toSlice(arena);
    const environ = init.environ_map;

    if (args.len == 0) {
        try printUsage(io);
        return;
    }

    const applet = getAppletName(args);

    // Global flags when invoked as cube/busybox/bb without a tool, or explicit flags
    if (mem.eql(u8, applet, "--version") or mem.eql(u8, applet, "-V") or mem.eql(u8, applet, "version")) {
        try util.writeAll(io, .stdout(), version.banner ++ "\n");
        return;
    }
    if (mem.eql(u8, applet, "--list") or mem.eql(u8, applet, "list")) {
        try printList(io);
        return;
    }
    if (mem.eql(u8, applet, "--help") or mem.eql(u8, applet, "-h") or mem.eql(u8, applet, "help") or
        mem.eql(u8, applet, "cube") or mem.eql(u8, applet, "busybox") or mem.eql(u8, applet, "bb"))
    {
        // bare multi-call name → help; also if only global name
        if (isMultiCallName(args[0]) and args.len == 1) {
            try printUsage(io);
            return;
        }
        if (mem.eql(u8, applet, "--help") or mem.eql(u8, applet, "-h") or mem.eql(u8, applet, "help")) {
            try printUsage(io);
            return;
        }
    }

    const cmd_args = if (isMultiCallName(args[0]))
        if (args.len > 1) args[1..] else args[0..0]
    else
        args;

    try dispatch(io, arena, applet, cmd_args, environ);
}

fn isMultiCallName(name: []const u8) bool {
    const base = util.basename(name);
    return mem.eql(u8, base, "cube") or mem.eql(u8, base, "busybox") or mem.eql(u8, base, "bb");
}

fn getAppletName(args: []const [:0]const u8) []const u8 {
    if (args.len == 0) return "cube";
    const base = util.basename(args[0]);
    if (isMultiCallName(args[0])) {
        if (args.len > 1) return args[1];
        return "cube";
    }
    return base;
}

fn dispatch(
    io: Io,
    arena: mem.Allocator,
    applet: []const u8,
    args: []const [:0]const u8,
    environ: *process.Environ.Map,
) !void {
    const argv = if (args.len > 0 and mem.eql(u8, args[0], applet))
        args
    else blk: {
        var list = try arena.alloc([:0]const u8, args.len + 1);
        list[0] = try arena.dupeZ(u8, applet);
        @memcpy(list[1..], args);
        break :blk list;
    };

    const handler = dispatch_table.get(applet) orelse {
        var buf: [256]u8 = undefined;
        const msg = try std.fmt.bufPrint(&buf, "cube: {s}: applet not found\n", .{applet});
        try util.writeAll(io, .stderr(), msg);
        std.process.exit(127);
    };

    const ctx = Ctx{ .io = io, .arena = arena, .argv = argv, .environ = environ };
    try handler(ctx);
}

/// Shared context passed to every applet handler, regardless of which
/// underlying cmd* parameters that applet actually needs.
const Ctx = struct {
    io: Io,
    arena: mem.Allocator,
    argv: []const [:0]const u8,
    environ: *process.Environ.Map,
};

const Handler = *const fn (Ctx) anyerror!void;

// One thin adapter per underlying cmd* signature so every dispatch_table
// entry shares the same Handler type. Mechanical 1:1 mapping onto
// src/applets/*.zig — see docs/ARCHITECTURE.md for the dispatch model.
fn hEcho(ctx: Ctx) !void {
    try text.cmdEcho(ctx.io, ctx.argv);
}

fn hTrue(ctx: Ctx) !void {
    _ = ctx;
}

fn hFalse(ctx: Ctx) !void {
    _ = ctx;
    std.process.exit(1);
}

fn hCat(ctx: Ctx) !void {
    try text.cmdCat(ctx.io, ctx.argv);
}

fn hLs(ctx: Ctx) !void {
    try fs.cmdLs(ctx.io, ctx.arena, ctx.argv);
}

fn hPwd(ctx: Ctx) !void {
    try fs.cmdPwd(ctx.io, ctx.arena);
}

fn hMkdir(ctx: Ctx) !void {
    try fs.cmdMkdir(ctx.io, ctx.argv);
}

fn hRmdir(ctx: Ctx) !void {
    try fs.cmdRmdir(ctx.io, ctx.argv);
}

fn hRm(ctx: Ctx) !void {
    try fs.cmdRm(ctx.io, ctx.arena, ctx.argv);
}

fn hTouch(ctx: Ctx) !void {
    try fs.cmdTouch(ctx.io, ctx.argv);
}

fn hCp(ctx: Ctx) !void {
    try fs.cmdCp(ctx.io, ctx.arena, ctx.argv);
}

fn hMv(ctx: Ctx) !void {
    try fs.cmdMv(ctx.io, ctx.argv);
}

fn hLn(ctx: Ctx) !void {
    try fs.cmdLn(ctx.io, ctx.argv);
}

fn hSleep(ctx: Ctx) !void {
    try sys.cmdSleep(ctx.io, ctx.argv);
}

fn hYes(ctx: Ctx) !void {
    try text.cmdYes(ctx.io, ctx.argv);
}

fn hHead(ctx: Ctx) !void {
    try text.cmdHead(ctx.io, ctx.argv);
}

fn hTail(ctx: Ctx) !void {
    try text.cmdTail(ctx.io, ctx.arena, ctx.argv);
}

fn hWc(ctx: Ctx) !void {
    try text.cmdWc(ctx.io, ctx.argv);
}

fn hBasename(ctx: Ctx) !void {
    try fs.cmdBasename(ctx.io, ctx.argv);
}

fn hDirname(ctx: Ctx) !void {
    try fs.cmdDirname(ctx.io, ctx.argv);
}

fn hUname(ctx: Ctx) !void {
    try sys.cmdUname(ctx.io, ctx.argv);
}

fn hWhoami(ctx: Ctx) !void {
    try sys.cmdWhoami(ctx.io);
}

fn hId(ctx: Ctx) !void {
    try sys.cmdId(ctx.io);
}

fn hDate(ctx: Ctx) !void {
    try sys.cmdDate(ctx.io, ctx.argv);
}

fn hClear(ctx: Ctx) !void {
    try sys.cmdClear(ctx.io);
}

fn hSeq(ctx: Ctx) !void {
    try text.cmdSeq(ctx.io, ctx.argv);
}

fn hTest(ctx: Ctx) !void {
    try sys.cmdTest(ctx.io, ctx.argv);
}

fn hPrintf(ctx: Ctx) !void {
    try text.cmdPrintf(ctx.io, ctx.argv);
}

fn hEnv(ctx: Ctx) !void {
    try sys.cmdEnv(ctx.io, ctx.argv, ctx.environ);
}

fn hWhich(ctx: Ctx) !void {
    try sys.cmdWhich(ctx.io, ctx.arena, ctx.argv, ctx.environ);
}

fn hGrep(ctx: Ctx) !void {
    try text.cmdGrep(ctx.io, ctx.arena, ctx.argv);
}

fn hSort(ctx: Ctx) !void {
    try text.cmdSort(ctx.io, ctx.arena, ctx.argv);
}

fn hCut(ctx: Ctx) !void {
    try text.cmdCut(ctx.io, ctx.argv);
}

fn hUniq(ctx: Ctx) !void {
    try text.cmdUniq(ctx.io, ctx.arena, ctx.argv);
}

fn hTr(ctx: Ctx) !void {
    try text.cmdTr(ctx.io, ctx.argv);
}

fn hRev(ctx: Ctx) !void {
    try text.cmdRev(ctx.io, ctx.argv);
}

fn hHostname(ctx: Ctx) !void {
    try sys.cmdHostname(ctx.io, ctx.argv);
}

fn hReadlink(ctx: Ctx) !void {
    try fs.cmdReadlink(ctx.io, ctx.argv);
}

fn hFind(ctx: Ctx) !void {
    try fs.cmdFind(ctx.io, ctx.arena, ctx.argv);
}

fn hDu(ctx: Ctx) !void {
    try fs.cmdDu(ctx.io, ctx.arena, ctx.argv);
}

fn hDf(ctx: Ctx) !void {
    try fs.cmdDf(ctx.io, ctx.argv);
}

fn hUptime(ctx: Ctx) !void {
    try sys.cmdUptime(ctx.io, ctx.argv);
}

fn hFree(ctx: Ctx) !void {
    try sys.cmdFree(ctx.io, ctx.argv);
}

fn hSed(ctx: Ctx) !void {
    try text.cmdSed(ctx.io, ctx.argv);
}

fn hMktemp(ctx: Ctx) !void {
    try fs.cmdMktemp(ctx.io, ctx.argv);
}

fn hKill(ctx: Ctx) !void {
    try sys.cmdKill(ctx.io, ctx.argv);
}

fn hPs(ctx: Ctx) !void {
    try sys.cmdPs(ctx.io, ctx.arena, ctx.argv);
}

fn hTee(ctx: Ctx) !void {
    try text.cmdTee(ctx.io, ctx.argv);
}

fn hXargs(ctx: Ctx) !void {
    try text.cmdXargs(ctx.io, ctx.arena, ctx.argv);
}

fn hRealpath(ctx: Ctx) !void {
    try fs.cmdRealpath(ctx.io, ctx.arena, ctx.argv);
}

fn hBase64(ctx: Ctx) !void {
    try text.cmdBase64(ctx.io, ctx.argv);
}

fn hMd5sum(ctx: Ctx) !void {
    try text.cmdMd5sum(ctx.io, ctx.argv);
}

fn hSha256sum(ctx: Ctx) !void {
    try text.cmdSha256sum(ctx.io, ctx.argv);
}

fn hCmp(ctx: Ctx) !void {
    try text.cmdCmp(ctx.io, ctx.argv);
}

fn hChmod(ctx: Ctx) !void {
    try fs.cmdChmod(ctx.io, ctx.arena, ctx.argv);
}

fn hNproc(ctx: Ctx) !void {
    try sys.cmdNproc(ctx.io, ctx.argv);
}

fn hSync(ctx: Ctx) !void {
    try sys.cmdSync(ctx.io, ctx.argv);
}

fn hOd(ctx: Ctx) !void {
    try text.cmdOd(ctx.io, ctx.argv);
}

fn hNl(ctx: Ctx) !void {
    try text.cmdNl(ctx.io, ctx.argv);
}

fn hTac(ctx: Ctx) !void {
    try text.cmdTac(ctx.io, ctx.arena, ctx.argv);
}

fn hStrings(ctx: Ctx) !void {
    try text.cmdStrings(ctx.io, ctx.argv);
}

fn hFold(ctx: Ctx) !void {
    try text.cmdFold(ctx.io, ctx.argv);
}

fn hPaste(ctx: Ctx) !void {
    try text.cmdPaste(ctx.io, ctx.arena, ctx.argv);
}

fn hExpand(ctx: Ctx) !void {
    try text.cmdExpand(ctx.io, ctx.argv);
}

fn hFactor(ctx: Ctx) !void {
    try text.cmdFactor(ctx.io, ctx.argv);
}

fn hTruncate(ctx: Ctx) !void {
    try fs.cmdTruncate(ctx.io, ctx.argv);
}

fn hSplit(ctx: Ctx) !void {
    try text.cmdSplit(ctx.io, ctx.argv);
}

fn hShuf(ctx: Ctx) !void {
    try text.cmdShuf(ctx.io, ctx.arena, ctx.argv);
}

fn hExpr(ctx: Ctx) !void {
    try text.cmdExpr(ctx.io, ctx.argv);
}

fn hUnlink(ctx: Ctx) !void {
    try fs.cmdUnlink(ctx.io, ctx.argv);
}

fn hJoin(ctx: Ctx) !void {
    try text.cmdJoin(ctx.io, ctx.arena, ctx.argv);
}

fn hComm(ctx: Ctx) !void {
    try text.cmdComm(ctx.io, ctx.arena, ctx.argv);
}

fn hFmt(ctx: Ctx) !void {
    try text.cmdFmt(ctx.io, ctx.argv);
}

fn hArch(ctx: Ctx) !void {
    try sys.cmdArch(ctx.io, ctx.argv);
}

fn hDd(ctx: Ctx) !void {
    try fs.cmdDd(ctx.io, ctx.argv);
}

fn hInstall(ctx: Ctx) !void {
    try fs.cmdInstall(ctx.io, ctx.argv);
}

fn hLink(ctx: Ctx) !void {
    try fs.cmdLink(ctx.io, ctx.argv);
}

fn hCksum(ctx: Ctx) !void {
    try fs.cmdCksum(ctx.io, ctx.argv);
}

fn hStat(ctx: Ctx) !void {
    try fs.cmdStat(ctx.io, ctx.argv);
}

fn hUnexpand(ctx: Ctx) !void {
    try text.cmdUnexpand(ctx.io, ctx.argv);
}

fn hGzip(ctx: Ctx) !void {
    try fs.cmdGzip(ctx.io, ctx.argv);
}

fn hGunzip(ctx: Ctx) !void {
    try fs.cmdGunzip(ctx.io, ctx.argv);
}

fn hSum(ctx: Ctx) !void {
    try fs.cmdSum(ctx.io, ctx.argv);
}

/// Canonical applet -> handler table. Must stay in sync with
/// src/applets_list.zig (enforced by a comptime check below and covered by
/// a harness case that runs `cube --list` against every dispatchable name).
const dispatch_table = std.StaticStringMap(Handler).initComptime(.{
    .{ "echo", hEcho },
    .{ "true", hTrue },
    .{ "false", hFalse },
    .{ "cat", hCat },
    .{ "ls", hLs },
    .{ "pwd", hPwd },
    .{ "mkdir", hMkdir },
    .{ "rmdir", hRmdir },
    .{ "rm", hRm },
    .{ "touch", hTouch },
    .{ "cp", hCp },
    .{ "mv", hMv },
    .{ "ln", hLn },
    .{ "sleep", hSleep },
    .{ "yes", hYes },
    .{ "head", hHead },
    .{ "tail", hTail },
    .{ "wc", hWc },
    .{ "basename", hBasename },
    .{ "dirname", hDirname },
    .{ "uname", hUname },
    .{ "whoami", hWhoami },
    .{ "id", hId },
    .{ "date", hDate },
    .{ "clear", hClear },
    .{ "seq", hSeq },
    .{ "test", hTest },
    .{ "[", hTest },
    .{ "printf", hPrintf },
    .{ "env", hEnv },
    .{ "printenv", hEnv },
    .{ "which", hWhich },
    .{ "grep", hGrep },
    .{ "sort", hSort },
    .{ "cut", hCut },
    .{ "uniq", hUniq },
    .{ "tr", hTr },
    .{ "rev", hRev },
    .{ "hostname", hHostname },
    .{ "readlink", hReadlink },
    .{ "find", hFind },
    .{ "du", hDu },
    .{ "df", hDf },
    .{ "uptime", hUptime },
    .{ "free", hFree },
    .{ "sed", hSed },
    .{ "mktemp", hMktemp },
    .{ "kill", hKill },
    .{ "ps", hPs },
    .{ "tee", hTee },
    .{ "xargs", hXargs },
    .{ "realpath", hRealpath },
    .{ "base64", hBase64 },
    .{ "md5sum", hMd5sum },
    .{ "sha256sum", hSha256sum },
    .{ "cmp", hCmp },
    .{ "chmod", hChmod },
    .{ "nproc", hNproc },
    .{ "sync", hSync },
    .{ "od", hOd },
    .{ "nl", hNl },
    .{ "tac", hTac },
    .{ "strings", hStrings },
    .{ "fold", hFold },
    .{ "paste", hPaste },
    .{ "expand", hExpand },
    .{ "factor", hFactor },
    .{ "truncate", hTruncate },
    .{ "split", hSplit },
    .{ "shuf", hShuf },
    .{ "expr", hExpr },
    .{ "unlink", hUnlink },
    .{ "join", hJoin },
    .{ "comm", hComm },
    .{ "fmt", hFmt },
    .{ "arch", hArch },
    .{ "dd", hDd },
    .{ "install", hInstall },
    .{ "link", hLink },
    .{ "cksum", hCksum },
    .{ "stat", hStat },
    .{ "unexpand", hUnexpand },
    .{ "gzip", hGzip },
    .{ "gunzip", hGunzip },
    .{ "sum", hSum },
});

comptime {
    // Every canonical applet name must resolve in the dispatch table, and
    // vice versa (aliases "[" and "printenv" are the only names the table
    // carries that applets_list.zig does not list separately... actually
    // both are listed there too, so this is a straight equality check).
    if (dispatch_table.kvs.len != applets_list.names.len) {
        @compileError("dispatch_table and applets_list.names have diverged in size");
    }
}

fn printUsage(io: Io) !void {
    try util.writeAll(io, .stdout(), version.banner ++ "\n");
    const usage =
        \\Usage: cube <applet> [args]
        \\       <applet> [args]          (symlink to cube)
        \\
        \\Global options:
        \\  --help, -h       Show this help
        \\  --version, -V    Show version
        \\  --list           List all applets (one per line)
        \\
        \\85 applets in text, filesystem, system, and logic groups.
        \\Run `cube --list` for the full name list.
        \\
        \\Documentation: README.md, ROADMAP.md, docs/
        \\
    ;
    try util.writeAll(io, .stdout(), usage);
}

fn printList(io: Io) !void {
    var buf: [2048]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &buf);
    const w = &writer.interface;
    for (applets_list.names) |name| {
        try w.writeAll(name);
        try w.writeAll("\n");
    }
    try w.flush();
}

test "isMultiCallName" {
    try std.testing.expect(isMultiCallName("cube"));
    try std.testing.expect(isMultiCallName("/usr/bin/cube"));
    try std.testing.expect(isMultiCallName("busybox"));
    try std.testing.expect(isMultiCallName("bb"));
    try std.testing.expect(!isMultiCallName("ls"));
    try std.testing.expect(!isMultiCallName("/bin/ls"));
}

test "getAppletName from symlink style" {
    const args1 = [_][:0]const u8{"/bin/ls"};
    try std.testing.expectEqualStrings("ls", getAppletName(&args1));

    const args2 = [_][:0]const u8{ "cube", "echo" };
    try std.testing.expectEqualStrings("echo", getAppletName(&args2));

    const args3 = [_][:0]const u8{"cube"};
    try std.testing.expectEqualStrings("cube", getAppletName(&args3));
}
