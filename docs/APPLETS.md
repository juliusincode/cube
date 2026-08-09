# Applets – overview

Status: Phase 1 (in progress)

| Applet     | Status | Important flags / behaviour                         | Notes |
|------------|--------|-----------------------------------------------------|-------|
| echo       | 🟡     | `-n`                                                | `-e` planned |
| true       | ✅     | exit 0                                              | |
| false      | ✅     | exit 1                                              | |
| cat        | 🟡     | multiple files, stdin                               | `-n` planned |
| ls         | ✅     | `-a -A -l -h -d -F`, sorted, multi-path             | owner/group optional |
| pwd        | ✅     |                                                     | |
| mkdir      | ✅     | `-p`                                                | `-m` later |
| rmdir      | ✅     |                                                     | |
| rm         | ✅     | `-r`/`-R`, `-f`, `-rf`                              | no `-i` |
| touch      | 🟡     | create / open                                       | improve mtime update |
| cp         | 🟡     | simple file copy                                    | `-r` planned |
| mv         | 🟡     | rename                                              | dir target planned |
| ln         | 🟡     | `-s`, hard link                                     | `-f` |
| sleep      | ✅     | seconds (float)                                     | |
| yes        | ✅     |                                                     | |
| head       | 🟡     | `-n`                                                | |
| tail       | 🟡     | `-n` (buffers all)                                  | |
| wc         | 🟡     | lines / words / bytes                               | flags planned |
| basename   | ✅     |                                                     | |
| dirname    | ✅     |                                                     | |
| uname      | 🟡     | fixed format                                        | `-a` etc. |
| whoami     | 🟡     | stub                                                | real UID |
| id         | 🟡     | stub                                                | real UID/GID |
| date       | 🟡     | Unix timestamp                                      | format string |
| clear      | ✅     | ANSI                                                | |
| seq        | ✅     | start [step] end                                    | |
| test / [   | 🟡     | very minimal                                        | expand |
| printf     | ✅     | `%s%d%i%u%x%X%c`, escapes `\n\t\r`                  | width/precision later |
| env        | ✅     | print all variables                                 | `env KEY=VAL cmd` later |
| printenv   | ✅     | single variable                                     | |
| which      | ⬜     |                                                     | |
| grep       | ⬜     |                                                     | Phase 2 |
| find       | ⬜     |                                                     | Phase 4 |

## Legend
- ✅ usable
- 🟡 basic; flags / edge cases missing
- ⬜ not implemented yet
