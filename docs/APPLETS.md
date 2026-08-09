# Applets – Übersicht

Stand: Phase 1 (in Arbeit)

| Applet     | Status | Wichtige Flags / Verhalten                          | Bemerkung |
|------------|--------|-----------------------------------------------------|-----------|
| echo       | 🟡     | `-n`                                                | `-e` geplant |
| true       | ✅     | Exit 0                                              | |
| false      | ✅     | Exit 1                                              | |
| cat        | 🟡     | mehrere Dateien, stdin                              | `-n` geplant |
| ls         | ✅     | `-a -A -l -h -d -F`, sortiert, multi-path           | owner/group optional |
| pwd        | ✅     |                                                     | |
| mkdir      | 🟡     |                                                     | `-p -m` geplant |
| rmdir      | ✅     |                                                     | |
| rm         | 🟡     | Dateien                                             | `-r -f` geplant |
| touch      | 🟡     | create / open                                       | mtime-Update verbessern |
| cp         | 🟡     | einfache Dateikopie                                 | `-r` geplant |
| mv         | 🟡     | rename                                              | Ziel-Dir geplant |
| ln         | 🟡     | `-s`, hardlink                                      | `-f` |
| sleep      | ✅     | Sekunden (float)                                    | |
| yes        | ✅     |                                                     | |
| head       | 🟡     | `-n`                                                | |
| tail       | 🟡     | `-n` (buffert alles)                                | |
| wc         | 🟡     | Zeilen/Wörter/Bytes                                 | Flags geplant |
| basename   | ✅     |                                                     | |
| dirname    | ✅     |                                                     | |
| uname      | 🟡     | festes Format                                       | `-a` etc. |
| whoami     | 🟡     | Stub                                                | echte UID |
| id         | 🟡     | Stub                                                | echte UID/GID |
| date       | 🟡     | Unix-Timestamp                                      | Format-String |
| clear      | ✅     | ANSI                                                | |
| seq        | ✅     | start [step] end                                    | |
| test / [   | 🟡     | sehr minimal                                        | erweitern |
| printf     | ✅     | `%s%d%i%u%x%X%c`, Escapes `\n\t\r`                  | Breite/Präzision später |
| env        | ✅     | alle Variablen ausgeben                             | `env KEY=VAL cmd` später |
| printenv   | ✅     | eine Variable                                       | |
| which      | ⬜     |                                                     | |
| grep       | ⬜     |                                                     | Phase 2 |
| find       | ⬜     |                                                     | Phase 4 |

## Legende
- ✅ brauchbar
- 🟡 grundlegend, Flags/Kantenfälle fehlen
- ⬜ noch nicht implementiert
