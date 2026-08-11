# Roadmap

**Goal:** A production-capable [BusyBox](https://www.busybox.net/)-style multi-call
binary in pure Zig 0.16+ — small, auditable, Linux-focused.

**Current release:** 0.3.0 — 76 applets, integration harness, modular layout.

## Status legend

| Symbol | Meaning |
|--------|---------|
| ✅ | Implemented (usable) |
| 🟡 | Partial / limited flags |
| ⬜ | Planned |
| ❌ | Out of scope for now |

## Phase 0 — Foundation ✅

- Multi-call dispatch (`argv[0]` / `cube <cmd>`)
- Zig 0.16 `process.Init`, `std.Io`
- Modules: `util`, `text`, `fs`, `sys`
- `ReleaseSmall` builds, MIT license, git-ready tree

## Phase 1 — Core utilities ✅

Everyday filesystem and shell tools: `ls`, `cp`, `mv`, `rm`, `mkdir`, `cat`,
`echo`, `head`, `tail`, `wc`, `test`, …

## Phase 2 — Text processing ✅ (core)

`grep` (fixed-string), `sed` (fixed `s///`), `sort`, `cut`, `uniq`, `tr`,
`tee`, `xargs`, `nl`, `tac`, `fold`, `fmt`, `paste`, `expand`, `split`, `shuf`,
`join`, `comm`, `base64`, `od`, `strings`, …

## Phase 3 — System introspection ✅ (subset)

`ps`, `kill`, `free`, `uptime`, `df`, `du`, `uname`, `arch`, `nproc`, `sync`, …

## Phase 4 — Next priorities

| Item | Status | Notes |
|------|--------|-------|
| Table-driven dispatch | ⬜ | Shared `Context` + handler table |
| Per-applet `--help` | ⬜ | |
| Richer `grep` (basic regex) | ⬜ | |
| `find` `-path` / `-iname` | ⬜ | |
| `chmod` symbolic modes / `-R` | ⬜ | |
| `tar` / `gzip` | ⬜ | Large effort |
| `ash` / shell | ⬜ | Major project |
| Networking (`wget`, `nc`, …) | ⬜ | |
| Feature/`CONFIG_*` build flags | ⬜ | Size tuning |
| CI (build + harness) | ⬜ | |

## Design principles

1. BusyBox behaviour over GNU when they diverge (unless POSIX requires otherwise)
2. No third-party dependencies in the default build
3. Prefer correctness and clarity over micro-optimizations
4. Every new applet: dispatch + `applets_list.zig` + APPLETS.md + harness case when practical

## Non-goals (near term)

- Full SELinux / complex enterprise utilities
- Windows as a primary target
- Drop-in replacement for every GNU coreutils flag
