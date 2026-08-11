//! cube version information (semver).
pub const major: u32 = 0;
pub const minor: u32 = 3;
pub const patch: u32 = 0;
pub const pre: []const u8 = "";

/// Human-readable version string, e.g. "0.3.0"
pub const string: []const u8 = "0.3.0";

/// Full identification line for --version
pub const banner: []const u8 = "cube " ++ string ++ " (Zig multi-call binary)";
