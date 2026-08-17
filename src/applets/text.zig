//! Aggregator for the `text` applet group.
//! Each applet lives in its own file under `text/`; see docs/ARCHITECTURE.md.

pub const cmdEcho = @import("text/echo.zig").cmdEcho;
pub const cmdCat = @import("text/cat.zig").cmdCat;
pub const cmdHead = @import("text/head.zig").cmdHead;
pub const cmdTail = @import("text/tail.zig").cmdTail;
pub const cmdWc = @import("text/wc.zig").cmdWc;
pub const cmdYes = @import("text/yes.zig").cmdYes;
pub const cmdSeq = @import("text/seq.zig").cmdSeq;
pub const cmdPrintf = @import("text/printf.zig").cmdPrintf;
pub const cmdGrep = @import("text/grep.zig").cmdGrep;
pub const cmdSort = @import("text/sort.zig").cmdSort;
pub const cmdCut = @import("text/cut.zig").cmdCut;
pub const cmdUniq = @import("text/uniq.zig").cmdUniq;
pub const cmdRev = @import("text/rev.zig").cmdRev;
pub const cmdTr = @import("text/tr.zig").cmdTr;
pub const cmdSed = @import("text/sed.zig").cmdSed;
pub const cmdTee = @import("text/tee.zig").cmdTee;
pub const cmdXargs = @import("text/xargs.zig").cmdXargs;
pub const cmdBase64 = @import("text/base64.zig").cmdBase64;
pub const cmdMd5sum = @import("text/md5sum.zig").cmdMd5sum;
pub const cmdSha256sum = @import("text/sha256sum.zig").cmdSha256sum;
pub const cmdCmp = @import("text/cmp.zig").cmdCmp;
pub const cmdOd = @import("text/od.zig").cmdOd;
pub const cmdNl = @import("text/nl.zig").cmdNl;
pub const cmdTac = @import("text/tac.zig").cmdTac;
pub const cmdStrings = @import("text/strings.zig").cmdStrings;
pub const cmdFold = @import("text/fold.zig").cmdFold;
pub const cmdPaste = @import("text/paste.zig").cmdPaste;
pub const cmdExpand = @import("text/expand.zig").cmdExpand;
pub const cmdFactor = @import("text/factor.zig").cmdFactor;
pub const cmdSplit = @import("text/split.zig").cmdSplit;
pub const cmdShuf = @import("text/shuf.zig").cmdShuf;
pub const cmdExpr = @import("text/expr.zig").cmdExpr;
pub const cmdJoin = @import("text/join.zig").cmdJoin;
pub const cmdComm = @import("text/comm.zig").cmdComm;
pub const cmdFmt = @import("text/fmt.zig").cmdFmt;
pub const cmdUnexpand = @import("text/unexpand.zig").cmdUnexpand;

// Force full container analysis of every split-out file so their
// `test` blocks are discovered by `zig build test` (plain field access
// like `@import(...).cmdX` above only analyzes that one decl lazily).
test {
    _ = @import("text/base64.zig");
    _ = @import("text/cat.zig");
    _ = @import("text/cmp.zig");
    _ = @import("text/comm.zig");
    _ = @import("text/common.zig");
    _ = @import("text/cut.zig");
    _ = @import("text/echo.zig");
    _ = @import("text/expand.zig");
    _ = @import("text/expr.zig");
    _ = @import("text/factor.zig");
    _ = @import("text/fmt.zig");
    _ = @import("text/fold.zig");
    _ = @import("text/grep.zig");
    _ = @import("text/head.zig");
    _ = @import("text/join.zig");
    _ = @import("text/md5sum.zig");
    _ = @import("text/nl.zig");
    _ = @import("text/od.zig");
    _ = @import("text/paste.zig");
    _ = @import("text/printf.zig");
    _ = @import("text/rev.zig");
    _ = @import("text/sed.zig");
    _ = @import("text/seq.zig");
    _ = @import("text/sha256sum.zig");
    _ = @import("text/shuf.zig");
    _ = @import("text/sort.zig");
    _ = @import("text/split.zig");
    _ = @import("text/strings.zig");
    _ = @import("text/tac.zig");
    _ = @import("text/tail.zig");
    _ = @import("text/tee.zig");
    _ = @import("text/tr.zig");
    _ = @import("text/unexpand.zig");
    _ = @import("text/uniq.zig");
    _ = @import("text/wc.zig");
    _ = @import("text/xargs.zig");
    _ = @import("text/yes.zig");
}
