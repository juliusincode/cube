const std = @import("std");
const Io = std.Io;
const process = std.process;
const mem = std.mem;
const builtin = @import("builtin");
const util = @import("util");

pub fn cmdExpr(io: Io, args: []const [:0]const u8) !void {
    // expr INTEGER OP INTEGER  — OP: + - * / %  and comparisons = > < >= <= !=
    // Also: expr length STRING, expr substr STRING POS LEN
    if (args.len < 2) {
        try util.writeAll(io, .stdout(), "0\n");
        return;
    }

    var wbuf: [256]u8 = undefined;
    var writer: Io.File.Writer = .initStreaming(.stdout(), io, &wbuf);
    const w = &writer.interface;

    // length S
    if (args.len >= 3 and mem.eql(u8, args[1], "length")) {
        try w.print("{d}\n", .{args[2].len});
        try w.flush();
        return;
    }
    // substr S POS LEN  (1-based pos)
    if (args.len >= 5 and mem.eql(u8, args[1], "substr")) {
        const s = args[2];
        const pos = std.fmt.parseInt(usize, args[3], 10) catch 1;
        const len = std.fmt.parseInt(usize, args[4], 10) catch 0;
        const start = if (pos == 0) 0 else pos -| 1;
        if (start >= s.len or len == 0) {
            try w.writeAll("\n");
        } else {
            const end = @min(start + len, s.len);
            try w.writeAll(s[start..end]);
            try w.writeAll("\n");
        }
        try w.flush();
        return;
    }

    // A OP B
    if (args.len >= 4) {
        const a = std.fmt.parseInt(i64, args[1], 10) catch {
            try util.writeAll(io, .stderr(), "expr: non-integer argument\n");
            std.process.exit(2);
        };
        const op = args[2];
        const b = std.fmt.parseInt(i64, args[3], 10) catch {
            try util.writeAll(io, .stderr(), "expr: non-integer argument\n");
            std.process.exit(2);
        };
        var result: i64 = 0;
        var is_bool = false;
        if (mem.eql(u8, op, "+")) {
            result = a +% b;
        } else if (mem.eql(u8, op, "-")) {
            result = a -% b;
        } else if (mem.eql(u8, op, "*") or mem.eql(u8, op, "\\*")) {
            result = a *% b;
        } else if (mem.eql(u8, op, "/")) {
            if (b == 0) {
                try util.writeAll(io, .stderr(), "expr: division by zero\n");
                std.process.exit(2);
            }
            result = @divTrunc(a, b);
        } else if (mem.eql(u8, op, "%")) {
            if (b == 0) {
                try util.writeAll(io, .stderr(), "expr: division by zero\n");
                std.process.exit(2);
            }
            result = @rem(a, b);
        } else if (mem.eql(u8, op, "=") or mem.eql(u8, op, "==")) {
            result = if (a == b) 1 else 0;
            is_bool = true;
        } else if (mem.eql(u8, op, "!=")) {
            result = if (a != b) 1 else 0;
            is_bool = true;
        } else if (mem.eql(u8, op, ">")) {
            result = if (a > b) 1 else 0;
            is_bool = true;
        } else if (mem.eql(u8, op, "<")) {
            result = if (a < b) 1 else 0;
            is_bool = true;
        } else if (mem.eql(u8, op, ">=")) {
            result = if (a >= b) 1 else 0;
            is_bool = true;
        } else if (mem.eql(u8, op, "<=")) {
            result = if (a <= b) 1 else 0;
            is_bool = true;
        } else {
            try util.writeAll(io, .stderr(), "expr: unknown operator\n");
            std.process.exit(2);
        }
        try w.print("{d}\n", .{result});
        try w.flush();
        if (is_bool and result == 0) std.process.exit(1);
        return;
    }

    // single arg: print it
    try w.writeAll(args[1]);
    try w.writeAll("\n");
    try w.flush();
}
