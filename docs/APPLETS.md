# Applets

Status for **cube 0.3.0**. Legend: ✅ usable · 🟡 limited · ⬜ planned.

Global: `cube --help` · `cube --version` · `cube --list`

## Shell and text

| Applet | Status | Notes |
|--------|--------|-------|
| echo | ✅ | `-n`, `-e` escapes |
| printf | ✅ | common format specs |
| cat | ✅ | multi-file |
| head | ✅ | `-n`, `-c` |
| tail | ✅ | `-n`, `-c` |
| wc | ✅ | `-l -w -c` |
| grep | ✅ | fixed-string; `-i -v -n -r -l -c -q -H -h` |
| sed | ✅ | fixed `s/pat/repl/[g]`; `-n` |
| sort | ✅ | `-n -r -u` |
| cut | ✅ | `-d -f -c` |
| uniq | ✅ | `-c -d -u` |
| tr | ✅ | translate / `-d`; ranges |
| rev | ✅ | reverse lines |
| tee | ✅ | `-a` append |
| xargs | ✅ | `-n`, `-0` / `-d`; spawn |
| nl | ✅ | `-ba` / `-bt` |
| tac | ✅ | reverse line order |
| fold | ✅ | `-w`, `-s` |
| fmt | ✅ | `-w` paragraph refill |
| paste | ✅ | `-d` delimiter |
| expand | ✅ | `-t` tab stops |
| split | ✅ | `-l` / `-b`; PREFIX |
| shuf | ✅ | lines or `-i LO-HI` |
| join | ✅ | sorted files; `-t` |
| comm | ✅ | `-123` |
| base64 | ✅ | `-d`, `-w` |
| od | ✅ | `-A x\|o\|n`, `-N` |
| strings | ✅ | `-n` |
| seq | ✅ | start [step] end |
| yes | ✅ | |
| expr | ✅ | arithmetic, compares, `length`, `substr` |
| factor | ✅ | prime factors |

## Filesystem

| Applet | Status | Notes |
|--------|--------|-------|
| ls | ✅ | long form, classify suffixes |
| pwd | ✅ | |
| mkdir | ✅ | `-p` |
| rmdir | ✅ | |
| rm | ✅ | |
| touch | ✅ | |
| cp | ✅ | |
| mv | ✅ | |
| ln | ✅ | `-s` |
| chmod | ✅ | octal modes; `-R` recursive |
| unlink | ✅ | |
| link | ✅ | hard link TARGET NAME |
| cksum | ✅ | CRC32 and size |
| stat | ✅ | file metadata summary |
| unexpand | ✅ | spaces to tabs; `-t`, `-a` |
| basename | ✅ | |
| dirname | ✅ | |
| readlink | ✅ | |
| realpath | ✅ | `.` / `..` resolution |
| find | ✅ | `-name`, `-iname`, `-path`, `-type`, `-maxdepth` |
| du | ✅ | `-s -h` |
| df | ✅ | `-h` |
| mktemp | ✅ | `-d`, `XXXXXX` |
| truncate | ✅ | `-s` with k/m/g |
| dd | ✅ | `if=` `of=` `bs=` `count=` `skip=` `seek=` |
| install | ✅ | `-m MODE`, `-d` directories |

## System

| Applet | Status | Notes |
|--------|--------|-------|
| uname | ✅ | `-a` and component flags |
| arch | ✅ | |
| hostname | ✅ | |
| whoami | ✅ | |
| id | ✅ | numeric ids |
| date | ✅ | `+FORMAT` |
| clear | ✅ | |
| sleep | ✅ | |
| uptime | ✅ | load averages |
| free | ✅ | `-h` |
| ps | ✅ | PID USER VSZ RSS STAT COMMAND; `-p` |
| kill | ✅ | signal name/number; `-l` |
| nproc | ✅ | |
| sync | ✅ | |
| which | ✅ | `$PATH` |
| env | ✅ | print environment |
| printenv | ✅ | |

## Logic and checksums

| Applet | Status | Notes |
|--------|--------|-------|
| true | ✅ | |
| false | ✅ | |
| test / `[` | ✅ | file and string/int tests |
| md5sum | ✅ | |
| sha256sum | ✅ | |
| cmp | ✅ | `-s` |

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Operational failure |
| 2 | Usage / operand error (selected tools) |
| 127 | Unknown applet |
