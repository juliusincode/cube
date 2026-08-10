# cube

**cube** is a pure-[Zig](https://ziglang.org/) multi-call binary: a single
executable that provides many common Unix utilities, in the spirit of
[BusyBox](https://www.busybox.net/).

The long-term goal is a **complete, production-capable BusyBox alternative**
— small, auditable, and written entirely in Zig 0.16+ with no C sources in
the project tree.

```text
cube 0.2.0 — multi-call core utilities for Linux
```

## Why cube?

| Goal | Approach |
|------|----------|
| One binary, many tools | Multi-call dispatch via `argv[0]` / `cube <cmd>` |
| Small footprint | `ReleaseSmall`, no third-party deps |
| Modern language | Zig 0.16 `std.Io`, explicit allocators |
| Honest scope | Tracked in [ROADMAP.md](ROADMAP.md); not every BusyBox applet yet |

## Quick start

```bash
# Requires Zig 0.16+
zig build -Doptimize=ReleaseSmall
./zig-out/bin/cube --version
./zig-out/bin/cube --list
./zig-out/bin/cube ls -la
./zig-out/bin/cube echo -e 'hello\nworld'

# Optional: install symlinks for drop-in use
ln -s "$(pwd)/zig-out/bin/cube" /usr/local/bin/ls   # example only
```

```bash
zig build test    # Zig unit tests
zig build run -- ps

# Integration harness (Python 3, no extra deps)
python3 tests/harness.py
python3 tests/harness.py --cube ./zig-out/bin/cube -v
```

## Global options

| Option | Meaning |
|--------|---------|
| `--help` / `-h` | Usage and applet summary |
| `--version` / `-V` | Version string |
| `--list` | Print every applet name (one per line) |

## Applets

Roughly **50+** utilities across text processing, filesystem, and system
introspection. See **[docs/APPLETS.md](docs/APPLETS.md)** for flags and status.

Examples:

```bash
# Filesystem
cube ls -la
cube find . -name '*.zig' -type f
cube du -sh .
cube realpath ../src

# Text
cube grep -n TODO src/main.zig
cube sed 's/foo/bar/g' file.txt
printf 'a\nb\nc\n' | cube xargs echo
echo 'payload' | cube tee -a log.txt

# System
cube ps -p 1
cube uname -a
cube free -h
```

## Project layout

```text
src/
  main.zig            Entry, dispatch, global flags
  util.zig            Shared helpers
  version.zig         Semver
  applets_list.zig    Canonical applet names
  applets/
    text.zig          echo, cat, grep, sed, sort, …
    fs.zig            ls, cp, find, du, df, …
    sys.zig           ps, kill, uname, free, …
docs/
  ARCHITECTURE.md     Internals
  APPLETS.md          Per-tool reference
  CONTRIBUTING.md     How to add applets
  STANDARDS.md        Engineering conventions
ROADMAP.md            Path to BusyBox parity
CHANGELOG.md
```

## Documentation

| Document | Contents |
|----------|----------|
| [ROADMAP.md](ROADMAP.md) | Phased plan toward full BusyBox coverage |
| [docs/STANDARDS.md](docs/STANDARDS.md) | Compatibility, CLI, code rules |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Dispatch and Zig 0.16 I/O model |
| [docs/APPLETS.md](docs/APPLETS.md) | Flags and maturity per applet |
| [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) | Adding tools and tests |
| [CHANGELOG.md](CHANGELOG.md) | Release history |

## Design principles

1. **Pure Zig** — no project-owned C; linux syscalls via Zig’s standard library
2. **BusyBox-first behaviour** when practical; document deviations
3. **Predictable errors** — `applet: message` on stderr, stable exit codes
4. **Modular growth** — new tools land in `text` / `fs` / `sys` with list + docs
5. **Test what is pure** — helpers under `zig build test`

## Status

**v0.2.0** — usable core and many everyday tools; not yet a full BusyBox
replacement. Kernel build systems, `ash`, and networking applets remain
future work (see roadmap).

## License

MIT — see [LICENSE](LICENSE)
