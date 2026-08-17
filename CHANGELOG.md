# Changelog

All notable changes to cube are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed

- `main.zig` dispatch replaced with a comptime `std.StaticStringMap(Handler)`
  keyed by applet name, backed by one thin adapter per `cmd*` signature,
  instead of an 85-way string-comparison chain. A comptime check fails the
  build if the table and `applets_list.names` diverge in size.
- Applet implementations split one-file-per-applet under
  `src/applets/{text,fs,sys}/`; `src/applets/{text,fs,sys}.zig` are now thin
  aggregators. Helpers shared by more than one applet in a group live in
  that group's `common.zig`. See `docs/ARCHITECTURE.md`.
- Added `.github/workflows/ci.yml`: `zig fmt --check`, Debug build, unit
  tests, ReleaseSmall build, and the integration harness run on every push
  and pull request.

## [0.3.0] — 2026-08-11

### Added

- Many text utilities: `nl`, `tac`, `strings`, `fold`, `fmt`, `paste`, `expand`,
  `split`, `shuf`, `join`, `comm`, `base64`, `od`, `expr`, `factor`, …
- Filesystem: `chmod`, `truncate`, `unlink`, `realpath`, `mktemp`, …
- System: `ps`, `kill`, `nproc`, `sync`, `arch`, `du`, `df`, `uptime`, `free`, …
- Checksums: `md5sum`, `sha256sum`; compare: `cmp`
- Python integration harness (`tests/harness.py`) with 110+ checks
- `docs/STANDARDS.md`, expanded architecture and applet reference

### Changed

- Documentation overhaul for a consistent, professional baseline
- Version banner and package metadata aligned to 0.3.0

## [0.2.0] — 2026-08-10

### Added

- Global flags: `--version`, `--list`
- `src/version.zig`, `src/applets_list.zig`
- Modular layout and initial professional docs
- Core and mid-tier applets through the 0.2 line

## [0.1.0] — 2026-08-09

### Added

- Initial multi-call binary on Zig 0.16
- Core applets: `echo`, `cat`, `ls`, `mkdir`, `rm`, `cp`, `mv`, …
