# Roadmap – cube

Goal: A **production-capable BusyBox alternative** in pure Zig 0.16+ —
small, auditable, multi-call, with behaviour aligned to BusyBox/POSIX where practical.

**Current release:** 0.2.0 — solid core + everyday tools; not full applet parity yet.

## Status legend
- ✅ implemented (basic / usable)
- 🟡 partial / incomplete
- ⬜ planned
- ❌ intentionally skipped (or later)

---

## Phase 0 – Foundation (done)
- ✅ Multi-call dispatch (`argv[0]` / `cube <cmd>`)
- ✅ Zig 0.16 APIs (`process.Init`, `Io`, `Dir`, `File`)
- ✅ ReleaseSmall build (~200 KB)
- ✅ Core applets: echo, true/false, cat, ls, pwd, mkdir, rmdir, rm, touch, cp, mv, ln, sleep, yes, head, tail, wc, basename, dirname, uname, whoami, id, date, clear, seq, test/[

## Phase 1 – Robustness & core utilities (mostly done)
Priority: make the most-used tools solid and practical.

| Applet           | Status | Next steps |
|------------------|--------|------------|
| echo             | ✅     | `-n -e -E`, escapes `\n \t \r` etc. |
| cat              | ✅     | `-n -b -s`, multi-file, stdin |
| ls               | ✅     | `-a -A -l -h -d -F` (no `-R` yet) |
| rm               | ✅     | `-r`/`-R`, `-f` (no `-i` yet) |
| cp               | ✅     | `-r`/`-R`, multi-src into dir (no `-p` yet) |
| mv               | ✅     | multi-src → directory |
| mkdir            | ✅     | `-p` (no `-m` yet) |
| touch            | ✅     | `-c`, mtime update |
| ln               | ✅     | `-s -f` |
| head/tail        | ✅     | `-n -c` both |
| wc               | ✅     | `-l -w -c`, multi-file totals |
| test / [         | ✅     | `-f -d -e -z -n -r -w -x -s`, `= != -eq…`, `!` |
| printf           | ✅     | `%s %d %i %u %x %X %c`, `\n \t \r` |
| env / printenv   | ✅     | all / single variable |
| which / type     | ✅/⬜  | `which` done; `type` later |
| dirname/basename | ✅     | optional suffix support |

**Phase 1 milestone:** All core file tools are everyday-usable and support the most important POSIX/BusyBox flags.

## Phase 2 – Text & search (mostly done)
| Applet       | Status | Notes |
|--------------|--------|-------|
| grep         | ✅     | fixed-string; `-i -v -n -r -l -c -q -H -h` |
| sed          | ✅     | fixed-string `s///` + `g`, `-n` |
| cut          | ✅     | `-d -f -c` |
| sort         | ✅     | `-n -r -u` |
| uniq         | ✅     | `-c -d -u` |
| tr           | ✅     | `-d`, ranges |
| rev          | ✅     | |
| od / hexdump | ⬜     | |

## Phase 3 – System & process (partial)
| Applet       | Status | Notes |
|--------------|--------|-------|
| ps           | ✅     | USER VSZ RSS STAT COMMAND, `-p` |
| kill         | ✅     | signals by name/number |
| killall      | ⬜     | |
| free         | ✅     | `-h` |
| uptime       | ✅     | |
| df           | ✅     | `-h` |
| du           | ✅     | `-s -h` |
| mount/umount | ⬜     | careful |
| hostname     | ✅     | |
| uname        | ✅     | `-a -s -n -r -v -m` |
| id/whoami    | ✅     | numeric uid/gid |
| date         | ✅     | `+FORMAT` |

## Phase 4 – Shell & scripting helpers
| Applet   | Status | Notes |
|----------|--------|-------|
| sh / ash | ❌/⬜  | large – optional later |
| xargs    | ✅     | `-n -0` |
| find     | ✅     | `-name` `*`/`?`, `-type f|d|l`, `-maxdepth` |
| expr     | ⬜     | |
| test     | 🟡     | expand |
| printf   | ✅     | |
| readlink | ✅     | |
| realpath | ✅     | |
| mktemp   | ✅     | |
| install  | ⬜     | |

## Phase 5 – Networking (optional)
| Applet    | Status |
|-----------|--------|
| ping      | ⬜     |
| wget/curl | ⬜     |
| nc        | ⬜     |
| ifconfig  | ⬜     |
| netstat   | ⬜     |

## Phase 6 – Architecture & quality
- ✅ Applets in modules (`src/applets/{text,fs,sys}.zig`)
- ✅ Shared helpers (`src/util.zig`)
- ⬜ Per-applet `--help`
- ✅ Unit tests (`zig build test`) for pure helpers
- ⬜ `CONFIG_*`-style compile-time feature toggles
- ⬜ Further size optimization (ReleaseSmall + strip)
- ⬜ Man pages / `cube --list`
- ⬜ Cross-compile examples (musl, aarch64, …)

---

## Next concrete steps (order)

1. `sed` (simple `s///`) / richer `grep`
2. `ps` / `kill`
3. `xargs` / `mktemp`
4. Per-applet `--help`
5. More unit / integration tests

## Design principles
- No C code – pure Zig
- Prefer small binary size
- POSIX/BusyBox behaviour where sensible and feasible
- Error messages in BusyBox style (`applet: msg`)
- No external dependencies
- Consistent use of the Zig 0.16 Io API
