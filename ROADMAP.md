# Roadmap

**Goal:** a production-capable [BusyBox](https://www.busybox.net/)-style multi-call
binary in pure Zig 0.16+, small, auditable, and Linux-focused.

**Current release:** 0.3.0 — 85 applets, integration test harness, modular source layout.

## Status legend

| Status | Meaning |
|--------|---------|
| Done | Implemented and usable |
| Partial | Implemented with limited flag coverage |
| Planned | Not yet started |
| Out of scope | Not planned for the near term |

## Phase 0 — Foundation

Status: Done

- Multi-call dispatch (`argv[0]` / `cube <applet>`)
- Zig 0.16 `process.Init`, `std.Io`
- Module split: `util`, `text`, `fs`, `sys`
- `ReleaseSmall` builds, MIT license, git-ready tree

## Phase 1 — Core utilities

Status: Done

Everyday filesystem and shell tools: `ls`, `cp`, `mv`, `rm`, `mkdir`, `cat`,
`echo`, `head`, `tail`, `wc`, `test`, and related applets.

## Phase 2 — Text processing

Status: Done (core feature set)

`grep` (fixed-string), `sed` (fixed `s///`), `sort`, `cut`, `uniq`, `tr`,
`tee`, `xargs`, `nl`, `tac`, `fold`, `fmt`, `paste`, `expand`, `split`, `shuf`,
`join`, `comm`, `base64`, `od`, `strings`, and related applets.

## Phase 3 — System introspection

Status: Done (subset of common tools)

`ps`, `kill`, `free`, `uptime`, `df`, `du`, `uname`, `arch`, `nproc`, `sync`,
and related applets.

## Phase 4 — Next priorities

| Item | Status | Notes |
|------|--------|-------|
| Table-driven dispatch | Done | `main.zig` now resolves applets through a `std.StaticStringMap(Handler)` keyed by name, with one thin per-signature adapter function per applet, instead of a string-comparison chain |
| Per-applet `--help` | Planned | Currently implemented for only a small subset of applets |
| Richer `grep` (basic regex) | Planned | Current implementation is fixed-string only |
| `find` `-path` / `-iname` extensions | Planned | |
| `chmod` symbolic modes / `-R` | Planned | |
| `tar` / full `gzip` feature set | Planned | Larger effort |
| `ash`-compatible shell | Planned | Major project |
| Networking (`wget`, `nc`, and similar) | Planned | |
| Feature / `CONFIG_*` build flags | Planned | For binary size tuning |
| Continuous integration (build + test harness) | Done | `.github/workflows/ci.yml`: `zig fmt --check`, Debug build, unit tests, ReleaseSmall build, `tests/harness.py` — all on every push and PR |

## Design principles

1. BusyBox behavior takes precedence over GNU coreutils when they diverge, unless POSIX requires otherwise.
2. No third-party dependencies in the default build.
3. Correctness and clarity take precedence over micro-optimization.
4. Every new applet ships with: dispatch wiring, an entry in `applets_list.zig`, an entry in `docs/APPLETS.md`, and a harness case where practical.

## Non-goals (near term)

- Full SELinux support or other complex enterprise-focused utilities
- Windows as a primary target
- A drop-in replacement for every GNU coreutils flag
