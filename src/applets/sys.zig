//! Aggregator for the `sys` applet group.
//! Each applet lives in its own file under `sys/`; see docs/ARCHITECTURE.md.

pub const cmdSleep = @import("sys/sleep.zig").cmdSleep;
pub const cmdUname = @import("sys/uname.zig").cmdUname;
pub const cmdWhoami = @import("sys/whoami.zig").cmdWhoami;
pub const cmdId = @import("sys/id.zig").cmdId;
pub const cmdDate = @import("sys/date.zig").cmdDate;
pub const cmdHostname = @import("sys/hostname.zig").cmdHostname;
pub const cmdUptime = @import("sys/uptime.zig").cmdUptime;
pub const cmdFree = @import("sys/free.zig").cmdFree;
pub const cmdPs = @import("sys/ps.zig").cmdPs;
pub const cmdKill = @import("sys/kill.zig").cmdKill;
pub const cmdNproc = @import("sys/nproc.zig").cmdNproc;
pub const cmdSync = @import("sys/sync.zig").cmdSync;
pub const cmdArch = @import("sys/arch.zig").cmdArch;
pub const cmdClear = @import("sys/clear.zig").cmdClear;
pub const cmdTest = @import("sys/test.zig").cmdTest;
pub const cmdEnv = @import("sys/env.zig").cmdEnv;
pub const cmdWhich = @import("sys/which.zig").cmdWhich;

// Force full container analysis of every split-out file so their
// `test` blocks are discovered by `zig build test` (plain field access
// like `@import(...).cmdX` above only analyzes that one decl lazily).
test {
    _ = @import("sys/arch.zig");
    _ = @import("sys/clear.zig");
    _ = @import("sys/date.zig");
    _ = @import("sys/env.zig");
    _ = @import("sys/free.zig");
    _ = @import("sys/hostname.zig");
    _ = @import("sys/id.zig");
    _ = @import("sys/kill.zig");
    _ = @import("sys/nproc.zig");
    _ = @import("sys/ps.zig");
    _ = @import("sys/sleep.zig");
    _ = @import("sys/sync.zig");
    _ = @import("sys/test.zig");
    _ = @import("sys/uname.zig");
    _ = @import("sys/uptime.zig");
    _ = @import("sys/which.zig");
    _ = @import("sys/whoami.zig");
}
