//! Aggregator for the `fs` applet group.
//! Each applet lives in its own file under `fs/`; see docs/ARCHITECTURE.md.

pub const cmdLs = @import("fs/ls.zig").cmdLs;
pub const cmdPwd = @import("fs/pwd.zig").cmdPwd;
pub const cmdMkdir = @import("fs/mkdir.zig").cmdMkdir;
pub const cmdRmdir = @import("fs/rmdir.zig").cmdRmdir;
pub const cmdRm = @import("fs/rm.zig").cmdRm;
pub const cmdTouch = @import("fs/touch.zig").cmdTouch;
pub const cmdCp = @import("fs/cp.zig").cmdCp;
pub const cmdMv = @import("fs/mv.zig").cmdMv;
pub const cmdLn = @import("fs/ln.zig").cmdLn;
pub const cmdBasename = @import("fs/basename.zig").cmdBasename;
pub const cmdDirname = @import("fs/dirname.zig").cmdDirname;
pub const cmdReadlink = @import("fs/readlink.zig").cmdReadlink;
pub const cmdFind = @import("fs/find.zig").cmdFind;
pub const cmdDu = @import("fs/du.zig").cmdDu;
pub const cmdDf = @import("fs/df.zig").cmdDf;
pub const cmdMktemp = @import("fs/mktemp.zig").cmdMktemp;
pub const cmdRealpath = @import("fs/realpath.zig").cmdRealpath;
pub const cmdChmod = @import("fs/chmod.zig").cmdChmod;
pub const cmdTruncate = @import("fs/truncate.zig").cmdTruncate;
pub const cmdUnlink = @import("fs/unlink.zig").cmdUnlink;
pub const cmdDd = @import("fs/dd.zig").cmdDd;
pub const cmdInstall = @import("fs/install.zig").cmdInstall;
pub const cmdLink = @import("fs/link.zig").cmdLink;
pub const cmdCksum = @import("fs/cksum.zig").cmdCksum;
pub const cmdStat = @import("fs/stat.zig").cmdStat;
pub const cmdGzip = @import("fs/gzip.zig").cmdGzip;
pub const cmdGunzip = @import("fs/gunzip.zig").cmdGunzip;
pub const cmdSum = @import("fs/sum.zig").cmdSum;

// Force full container analysis of every split-out file so their
// `test` blocks are discovered by `zig build test` (plain field access
// like `@import(...).cmdX` above only analyzes that one decl lazily).
test {
    _ = @import("fs/basename.zig");
    _ = @import("fs/chmod.zig");
    _ = @import("fs/cksum.zig");
    _ = @import("fs/common.zig");
    _ = @import("fs/cp.zig");
    _ = @import("fs/dd.zig");
    _ = @import("fs/df.zig");
    _ = @import("fs/dirname.zig");
    _ = @import("fs/du.zig");
    _ = @import("fs/find.zig");
    _ = @import("fs/gunzip.zig");
    _ = @import("fs/gzip.zig");
    _ = @import("fs/install.zig");
    _ = @import("fs/link.zig");
    _ = @import("fs/ln.zig");
    _ = @import("fs/ls.zig");
    _ = @import("fs/mkdir.zig");
    _ = @import("fs/mktemp.zig");
    _ = @import("fs/mv.zig");
    _ = @import("fs/pwd.zig");
    _ = @import("fs/readlink.zig");
    _ = @import("fs/realpath.zig");
    _ = @import("fs/rm.zig");
    _ = @import("fs/rmdir.zig");
    _ = @import("fs/stat.zig");
    _ = @import("fs/sum.zig");
    _ = @import("fs/touch.zig");
    _ = @import("fs/truncate.zig");
    _ = @import("fs/unlink.zig");
}
