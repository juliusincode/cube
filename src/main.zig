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
    return mem.eql(u8, base, "cube")
        or mem.eql(u8, base, "busybox")
        or mem.eql(u8, base, "bb");
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

    if (mem.eql(u8, applet, "echo")) {
        try text.cmdEcho(io, argv);
    } else if (mem.eql(u8, applet, "true")) {
        // exit 0
    } else if (mem.eql(u8, applet, "false")) {
        std.process.exit(1);
    } else if (mem.eql(u8, applet, "cat")) {
        try text.cmdCat(io, argv);
    } else if (mem.eql(u8, applet, "ls")) {
        try fs.cmdLs(io, arena, argv);
    } else if (mem.eql(u8, applet, "pwd")) {
        try fs.cmdPwd(io, arena);
    } else if (mem.eql(u8, applet, "mkdir")) {
        try fs.cmdMkdir(io, argv);
    } else if (mem.eql(u8, applet, "rmdir")) {
        try fs.cmdRmdir(io, argv);
    } else if (mem.eql(u8, applet, "rm")) {
        try fs.cmdRm(io, arena, argv);
    } else if (mem.eql(u8, applet, "touch")) {
        try fs.cmdTouch(io, argv);
    } else if (mem.eql(u8, applet, "cp")) {
        try fs.cmdCp(io, arena, argv);
    } else if (mem.eql(u8, applet, "mv")) {
        try fs.cmdMv(io, argv);
    } else if (mem.eql(u8, applet, "ln")) {
        try fs.cmdLn(io, argv);
    } else if (mem.eql(u8, applet, "sleep")) {
        try sys.cmdSleep(io, argv);
    } else if (mem.eql(u8, applet, "yes")) {
        try text.cmdYes(io, argv);
    } else if (mem.eql(u8, applet, "head")) {
        try text.cmdHead(io, argv);
    } else if (mem.eql(u8, applet, "tail")) {
        try text.cmdTail(io, arena, argv);
    } else if (mem.eql(u8, applet, "wc")) {
        try text.cmdWc(io, argv);
    } else if (mem.eql(u8, applet, "basename")) {
        try fs.cmdBasename(io, argv);
    } else if (mem.eql(u8, applet, "dirname")) {
        try fs.cmdDirname(io, argv);
    } else if (mem.eql(u8, applet, "uname")) {
        try sys.cmdUname(io, argv);
    } else if (mem.eql(u8, applet, "whoami")) {
        try sys.cmdWhoami(io);
    } else if (mem.eql(u8, applet, "id")) {
        try sys.cmdId(io);
    } else if (mem.eql(u8, applet, "date")) {
        try sys.cmdDate(io, argv);
    } else if (mem.eql(u8, applet, "clear")) {
        try sys.cmdClear(io);
    } else if (mem.eql(u8, applet, "seq")) {
        try text.cmdSeq(io, argv);
    } else if (mem.eql(u8, applet, "test") or mem.eql(u8, applet, "[")) {
        try sys.cmdTest(io, argv);
    } else if (mem.eql(u8, applet, "printf")) {
        try text.cmdPrintf(io, argv);
    } else if (mem.eql(u8, applet, "env") or mem.eql(u8, applet, "printenv")) {
        try sys.cmdEnv(io, argv, environ);
    } else if (mem.eql(u8, applet, "which")) {
        try sys.cmdWhich(io, arena, argv, environ);
    } else if (mem.eql(u8, applet, "grep")) {
        try text.cmdGrep(io, arena, argv);
    } else if (mem.eql(u8, applet, "sort")) {
        try text.cmdSort(io, arena, argv);
    } else if (mem.eql(u8, applet, "cut")) {
        try text.cmdCut(io, argv);
    } else if (mem.eql(u8, applet, "uniq")) {
        try text.cmdUniq(io, arena, argv);
    } else if (mem.eql(u8, applet, "tr")) {
        try text.cmdTr(io, argv);
    } else if (mem.eql(u8, applet, "rev")) {
        try text.cmdRev(io, argv);
    } else if (mem.eql(u8, applet, "hostname")) {
        try sys.cmdHostname(io, argv);
    } else if (mem.eql(u8, applet, "readlink")) {
        try fs.cmdReadlink(io, argv);
    } else if (mem.eql(u8, applet, "find")) {
        try fs.cmdFind(io, arena, argv);
    } else if (mem.eql(u8, applet, "du")) {
        try fs.cmdDu(io, arena, argv);
    } else if (mem.eql(u8, applet, "df")) {
        try fs.cmdDf(io, argv);
    } else if (mem.eql(u8, applet, "uptime")) {
        try sys.cmdUptime(io, argv);
    } else if (mem.eql(u8, applet, "free")) {
        try sys.cmdFree(io, argv);
    } else if (mem.eql(u8, applet, "sed")) {
        try text.cmdSed(io, argv);
    } else if (mem.eql(u8, applet, "mktemp")) {
        try fs.cmdMktemp(io, argv);
    } else if (mem.eql(u8, applet, "kill")) {
        try sys.cmdKill(io, argv);
    } else if (mem.eql(u8, applet, "ps")) {
        try sys.cmdPs(io, arena, argv);
    } else if (mem.eql(u8, applet, "tee")) {
        try text.cmdTee(io, argv);
    } else if (mem.eql(u8, applet, "xargs")) {
        try text.cmdXargs(io, arena, argv);
    } else if (mem.eql(u8, applet, "realpath")) {
        try fs.cmdRealpath(io, arena, argv);
    } else {
        var buf: [256]u8 = undefined;
        const msg = try std.fmt.bufPrint(&buf, "cube: {s}: applet not found\n", .{applet});
        try util.writeAll(io, .stderr(), msg);
        std.process.exit(127);
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
        \\Applets (also: cube --list):
        \\  echo true false cat ls pwd mkdir rmdir rm touch cp mv ln
        \\  sleep yes head tail wc basename dirname uname whoami id
        \\  date clear seq test [ printf env printenv which grep
        \\  sort cut uniq tr rev hostname readlink find du df
        \\  uptime free sed mktemp kill ps tee xargs realpath
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
