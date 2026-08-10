# Changelog

All notable changes to cube are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [0.2.0] — 2026-08-10

### Added

- Applets: `tee`, `xargs`, `realpath`
- Global flags: `--version`, `--list`
- `src/version.zig`, `src/applets_list.zig`
- Engineering standards (`docs/STANDARDS.md`)
- Applets through 0.2 development line: text tools (`grep`, `sort`, `cut`,
  `uniq`, `tr`, `rev`, `sed`), filesystem (`find`, `du`, `df`, `mktemp`,
  `readlink`), system (`ps`, `kill`, `uptime`, `free`, `hostname`, …)
- Unit tests for pure helpers (`zig build test`)

### Changed

- Modular layout: `util` + `applets/{text,fs,sys}`
- Professional project documentation and roadmap toward BusyBox parity

## [0.1.0] — 2026-08-09

### Added

- Initial multi-call binary on Zig 0.16
- Core applets: `echo`, `cat`, `ls`, `mkdir`, `rm`, `cp`, `mv`, …
