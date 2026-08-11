# cube

**cube** is a pure-[Zig](https://ziglang.org/) multi-call binary in the spirit of
[BusyBox](https://www.busybox.net/): one executable, many common Unix utilities.

```text
cube 0.3.0 — multi-call utilities for Linux
```

Long-term goal: a **production-capable BusyBox alternative** — small, auditable,
and written entirely in Zig 0.16+ with no C sources in the project tree.

```bash
cube ls -la
cube grep -n TODO src/
cube find . -name '*.zig' -type f
ln -s cube grep && ./grep -n pattern file.txt
```

## Status

| Item | State |
|------|--------|
| Release | **0.3.0** |
| Applets | **85** (`cube --list`) |
| Integration tests | **110+** (`tests/harness.py`) |
| Zig | **0.16+** |
| Full BusyBox parity | Not yet (see [ROADMAP.md](ROADMAP.md)) |

## Requirements

- [Zig 0.16](https://ziglang.org/download/) or newer
- Linux (primary target; uses `/proc`, Linux syscalls where needed)

## Build

```bash
zig build -Doptimize=ReleaseSmall   # preferred
zig build -Doptimize=Debug
zig build test                      # Zig unit tests
zig build run -- --list
```

Binary: `zig-out/bin/cube`

## Usage

```bash
cube --help
cube --version
cube --list
cube <applet> [args...]
```

Multi-call names recognized as the dispatcher: `cube`, `busybox`, `bb`.  
Symlink any applet name to the binary to invoke it directly.

### Global options

| Option | Meaning |
|--------|---------|
| `--help`, `-h` | Usage summary |
| `--version`, `-V` | Version banner |
| `--list` | All applet names, one per line |

## Applets (overview)

| Group | Examples |
|-------|----------|
| **Shell / text** | `echo` `printf` `cat` `head` `tail` `wc` `grep` `sed` `sort` `cut` `uniq` `tr` `rev` `tee` `xargs` `nl` `tac` `fold` `fmt` `paste` `expand` `split` `shuf` `join` `comm` `base64` `od` `strings` `seq` `yes` `expr` `factor` |
| **Filesystem** | `ls` `pwd` `mkdir` `rmdir` `rm` `touch` `cp` `mv` `ln` `chmod` `unlink` `basename` `dirname` `readlink` `realpath` `find` `du` `df` `mktemp` `truncate` `dd` `install` `gzip`/`gunzip` |
| **System** | `uname` `arch` `hostname` `whoami` `id` `date` `clear` `sleep` `uptime` `free` `ps` `kill` `nproc` `sync` `which` `env` `printenv` |
| **Logic / hash** | `true` `false` `test` `[` `md5sum` `sha256sum` `cmp` |

Full flags and maturity: **[docs/APPLETS.md](docs/APPLETS.md)**

### Examples

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
echo payload | cube tee -a log.txt
cube expr 3 + 4

# System
cube ps -p 1
cube uname -a
cube free -h
cube arch
```

## Project layout

```text
src/
  main.zig              entry, multi-call dispatch, global flags
  util.zig              shared I/O helpers
  version.zig           semver constants
  applets_list.zig      canonical sorted names for --list
  applets/
    text.zig            text processing and filters
    fs.zig              filesystem tools
    sys.zig             process and system tools
docs/
  ARCHITECTURE.md       internals and Zig 0.16 Io notes
  APPLETS.md            per-applet flags and status
  CONTRIBUTING.md       how to add applets
  STANDARDS.md          engineering conventions
tests/
  harness.py            integration suite (Python 3, no deps)
  README.md
ROADMAP.md
CHANGELOG.md
LICENSE
```

## Documentation

| Document | Contents |
|----------|----------|
| [ROADMAP.md](ROADMAP.md) | Phased plan toward BusyBox parity |
| [docs/STANDARDS.md](docs/STANDARDS.md) | Compatibility, CLI, code rules |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Dispatch model, modules, I/O |
| [docs/APPLETS.md](docs/APPLETS.md) | Flags and status per applet |
| [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) | Adding tools and tests |
| [CHANGELOG.md](CHANGELOG.md) | Release history |

## Testing

```bash
zig build test

zig build -Doptimize=ReleaseSmall
python3 tests/harness.py
python3 tests/harness.py --cube ./zig-out/bin/cube -v
# or: CUBE=/path/to/cube python3 tests/harness.py
```

The harness runs applets in a private temporary directory and checks exit codes
and output contracts. Exit status is `0` only if every case passes.

## Design principles

1. **Pure Zig** — no project-owned C; Linux via Zig’s standard library  
2. **BusyBox-first behaviour** when practical; document deviations  
3. **Predictable errors** — `applet: message` on stderr; stable exit codes  
4. **Modular growth** — `text` / `fs` / `sys` plus list + docs for every applet  
5. **Test pure helpers** under `zig build test`; integration via the harness  

## License

MIT — see [LICENSE](LICENSE)
