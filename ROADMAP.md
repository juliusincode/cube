# Roadmap – cube

Goal: An educational, modular, and reasonably compatible BusyBox-style multi-call binary written in pure Zig 0.16.

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

## Phase 1 – Robustness & core utilities (current)
Priority: make the most-used tools solid and practical.

| Applet           | Status | Next steps |
|------------------|--------|------------|
| echo             | 🟡     | `-e` / `-E`, escape sequences |
| cat              | 🟡     | `-n`, `-b`, `-s` |
| ls               | ✅     | `-a -A -l -h -d -F` (no `-R` yet) |
| rm               | ✅     | `-r`/`-R`, `-f` (no `-i` yet) |
| cp               | 🟡     | `-r`, `-p`, `-v`, directory target |
| mv               | 🟡     | directory target, `-v` |
| mkdir            | ✅     | `-p` (no `-m` yet) |
| touch            | 🟡     | mtime update, `-c` |
| ln               | 🟡     | `-f` |
| head/tail        | 🟡     | `-c`, `-q`/`-v` |
| wc               | 🟡     | `-l`/`-w`/`-c` flags |
| test / [         | 🟡     | real checks (`-f`, `-d`, `-e`, …) |
| printf           | ✅     | `%s %d %i %u %x %X %c`, `\n \t \r` |
| env / printenv   | ✅     | all / single variable |
| which / type     | ⬜     | new |
| dirname/basename | ✅     | optional suffix support |

**Phase 1 milestone:** All core file tools are everyday-usable and support the most important POSIX/BusyBox flags.

## Phase 2 – Text & search
| Applet       | Status | Notes |
|--------------|--------|-------|
| grep         | ⬜     | basic + `-i`, `-v`, `-n`, `-r` |
| sed          | ⬜     | simple `s///` only |
| cut          | ⬜     | `-d`, `-f`, `-c` |
| sort         | ⬜     | `-n`, `-r`, `-u` |
| uniq         | ⬜     | |
| tr           | ⬜     | |
| rev          | ⬜     | |
| od / hexdump | ⬜     | |

## Phase 3 – System & process
| Applet       | Status | Notes |
|--------------|--------|-------|
| ps           | ⬜     | `/proc`-based |
| kill         | ⬜     | |
| killall      | ⬜     | |
| free         | ⬜     | |
| uptime       | ⬜     | |
| df           | ⬜     | |
| du           | ⬜     | |
| mount/umount | ⬜     | careful |
| hostname     | ⬜     | |
| uname        | 🟡     | more flags (`-a`, `-s`, …) |
| id/whoami    | 🟡     | real UID/GID via posix |
| date         | 🟡     | format string (`+…`) |

## Phase 4 – Shell & scripting helpers
| Applet   | Status | Notes |
|----------|--------|-------|
| sh / ash | ❌/⬜  | large – optional later |
| xargs    | ⬜     | |
| find     | ⬜     | basic + `-name`, `-type` |
| expr     | ⬜     | |
| test     | 🟡     | expand |
| printf   | ✅     | |
| readlink | ⬜     | |
| realpath | ⬜     | |
| mktemp   | ⬜     | |
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
- ⬜ Applets in separate modules (`src/applets/*.zig`)
- ⬜ Shared helpers (`src/util.zig`: flags, paths, error printing)
- ⬜ Per-applet `--help`
- ⬜ Tests (at least for pure functions)
- ⬜ `CONFIG_*`-style compile-time feature toggles
- ⬜ Further size optimization (ReleaseSmall + strip)
- ⬜ Man pages / `cube --list`
- ⬜ Cross-compile examples (musl, aarch64, …)

---

## Next concrete steps (order)

1. Documentation & structure ← *done*
2. `printf` ← *done*
3. `rm -r` / `rm -f` ← *done*
4. `mkdir -p` ← *done*
5. Better `ls` (`-l`, `-a`, …) ← *done*
6. Expand `test` / `[`
7. `cp -r`
8. `which`
9. `grep` (basic)
10. Refactor into modules

## Design principles
- No C code – pure Zig
- Prefer small binary size
- POSIX/BusyBox behaviour where sensible and feasible
- Error messages in BusyBox style (`applet: msg`)
- No external dependencies
- Consistent use of the Zig 0.16 Io API
