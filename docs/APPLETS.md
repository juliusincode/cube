# Applets

Status for **cube 0.3.0**. Status column: Done (usable), Partial (limited flag coverage), Planned (not yet implemented).

Global: `cube --help` · `cube --version` · `cube --list`

## Shell and text

| Applet | Status | Notes |
|--------|--------|-------|
| echo | Done | `-n`, `-e` escapes |
| printf | Done | common format specs |
| cat | Done | multi-file |
| head | Done | `-n`, `-c` |
| tail | Done | `-n`, `-c` |
| wc | Done | `-l -w -c` |
| grep | Done | fixed-string; `-i -v -n -r -l -c -q -H -h` |
| sed | Done | fixed `s/pat/repl/[g]`; `-n` |
| sort | Done | `-n -r -u` |
| cut | Done | `-d -f -c` |
| uniq | Done | `-c -d -u` |
| tr | Done | translate / `-d`; ranges |
| rev | Done | reverse lines |
| tee | Done | `-a` append |
| xargs | Done | `-n`, `-0` / `-d`; spawn |
| nl | Done | `-ba` / `-bt` |
| tac | Done | reverse line order |
| fold | Done | `-w`, `-s` |
| fmt | Done | `-w` paragraph refill |
| paste | Done | `-d` delimiter |
| expand | Done | `-t` tab stops |
| split | Done | `-l` / `-b`; PREFIX |
| shuf | Done | lines or `-i LO-HI` |
| join | Done | sorted files; `-t` |
| comm | Done | `-123` |
| base64 | Done | `-d`, `-w` |
| od | Done | `-A x\|o\|n`, `-N` |
| strings | Done | `-n` |
| seq | Done | start [step] end |
| yes | Done | |
| expr | Done | arithmetic, compares, `length`, `substr` |
| factor | Done | prime factors |

## Filesystem

| Applet | Status | Notes |
|--------|--------|-------|
| ls | Done | long form, classify suffixes |
| pwd | Done | |
| mkdir | Done | `-p`, `-m MODE` |
| rmdir | Done | |
| rm | Done | |
| touch | Done | |
| cp | Done | |
| mv | Done | |
| ln | Done | `-s` |
| chmod | Done | octal modes; `-R` recursive |
| unlink | Done | |
| link | Done | hard link TARGET NAME |
| cksum | Done | CRC32 and size |
| sum | Done | BSD-style checksum |
| stat | Done | file metadata summary |
| unexpand | Done | spaces to tabs; `-t`, `-a` |
| gzip | Done | compress + decompress (`-d`, `-c`) |
| gunzip | Done | alias for `gzip -d` |
| basename | Done | optional SUFFIX strip |
| dirname | Done | multiple paths |
| readlink | Done | |
| realpath | Done | `.` / `..` resolution |
| find | Done | `-name`, `-iname`, `-path`, `-type`, `-maxdepth` |
| du | Done | `-s -h` |
| df | Done | `-h` |
| mktemp | Done | `-d`, `XXXXXX` |
| truncate | Done | `-s` with k/m/g |
| dd | Done | `if=` `of=` `bs=` `count=` `skip=` `seek=` |
| install | Done | `-m MODE`, `-d` directories |

## System

| Applet | Status | Notes |
|--------|--------|-------|
| uname | Done | `-a` and component flags |
| arch | Done | |
| hostname | Done | |
| whoami | Done | |
| id | Done | numeric ids |
| date | Done | `+FORMAT` |
| clear | Done | |
| sleep | Done | |
| uptime | Done | load averages |
| free | Done | `-h` |
| ps | Done | PID USER VSZ RSS STAT COMMAND; `-p` |
| kill | Done | signal name/number; `-l` |
| nproc | Done | |
| sync | Done | |
| which | Done | `$PATH` |
| env | Done | print environment |
| printenv | Done | |

## Logic and checksums

| Applet | Status | Notes |
|--------|--------|-------|
| true | Done | |
| false | Done | |
| test / `[` | Done | file and string/int tests |
| md5sum | Done | |
| sha256sum | Done | |
| cmp | Done | `-s` |

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Operational failure |
| 2 | Usage / operand error (selected tools) |
| 127 | Unknown applet |
