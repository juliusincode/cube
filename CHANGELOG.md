# Changelog

All notable changes to cube are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

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

- Documentation overhaul for a clearer project professional baseline
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
