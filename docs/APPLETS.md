# Applets – overview

Status: Phase 1–3 (core + text + system subset)

| Applet     | Status | Important flags / behaviour                         | Notes |
|------------|--------|-----------------------------------------------------|-------|
| echo       | ✅     | `-n -e -E`, escapes                                 | |
| true       | ✅     | exit 0                                              | |
| false      | ✅     | exit 1                                              | |
| cat        | ✅     | `-n -b -s`, multi-file, stdin                       | |
| ls         | ✅     | `-a -A -l -h -d -F`, sorted, multi-path             | owner/group optional |
| pwd        | ✅     |                                                     | |
| mkdir      | ✅     | `-p`                                                | `-m` later |
| rmdir      | ✅     |                                                     | |
| rm         | ✅     | `-r`/`-R`, `-f`, `-rf`                              | no `-i` |
| touch      | ✅     | `-c`, create / update mtime                         | |
| cp         | ✅     | `-r`/`-R`, multi-src → dir                          | no `-p` |
| mv         | ✅     | rename, multi-src → directory                       | |
| ln         | ✅     | `-s -f`, hard/symlink                               | |
| sleep      | ✅     | seconds (float)                                     | |
| yes        | ✅     |                                                     | |
| head       | ✅     | `-n`, `-c`, historic `-N`                           | |
| tail       | ✅     | `-n`, `-c` (buffers input)                          | |
| wc         | ✅     | `-l -w -c`, multi-file total                        | |
| basename   | ✅     |                                                     | |
| dirname    | ✅     |                                                     | |
| uname      | ✅     | `-a -s -n -r -v -m`                                 | |
| whoami     | ✅     | numeric uid                                         | name via passwd later |
| id         | ✅     | uid/gid/euid/egid numeric                           | |
| date       | ✅     | `+%Y-%m-%d…`, `%s %H %M %S %a %b`                   | UTC |
| clear      | ✅     | ANSI                                                | |
| seq        | ✅     | start [step] end                                    | |
| test / [   | ✅     | file tests, string/int compares, `!`                | no `-a`/`-o` yet |
| printf     | ✅     | `%s%d%i%u%x%X%c`, escapes `\n\t\r`                  | width/precision later |
| env        | ✅     | print all variables                                 | `env KEY=VAL cmd` later |
| printenv   | ✅     | single variable                                     | |
| which      | ✅     | search `$PATH`                                      | |
| grep       | ✅     | `-i -v -n -r -l -c -q -H -h` (fixed-string)         | full regex later |
| sort       | ✅     | `-n -r -u`                                          | |
| cut        | ✅     | `-d -f -c`                                          | |
| uniq       | ✅     | `-c -d -u`                                          | |
| tr         | ✅     | translate / `-d` delete, ranges `a-z`               | |
| rev        | ✅     | reverse lines                                       | |
| hostname   | ✅     | print nodename                                      | |
| readlink   | ✅     | resolve symlink (`-n`)                              | |
| find       | ✅     | `-name` glob, `-type f|d|l`, `-maxdepth`            | |
| du         | ✅     | `-s -h`, directory totals                           | |
| df         | ✅     | `-h`, from `/proc/mounts` + statfs                  | |
| uptime     | ✅     | uptime + load average                               | |
| free       | ✅     | `-h`, mem/swap via sysinfo                          | |
| tee        | ✅     | copy stdin to stdout and files; `-a`                | |
| xargs      | ✅     | `-n`, `-0`/`-d`, spawn command                      | |
| realpath   | ✅     | resolve `.` / `..` to absolute path                 | |
| sed        | ✅     | `s/pat/repl/[g]`, `-n` (fixed-string)               | no regex |
| mktemp     | ✅     | `-d`, TEMPLATE with `XXXXXX`                        | |
| kill       | ✅     | `-SIGNAL` / `-n`, `-l`, pid…                        | |
| ps         | ✅     | PID USER VSZ RSS STAT COMMAND; `-p PID`             | |

## Legend
- ✅ usable
- 🟡 basic; flags / edge cases missing
- ⬜ not implemented yet
