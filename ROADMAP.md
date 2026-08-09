# Roadmap – cube

Ziel: Ein lehrreicher, modularer und möglichst kompatibler Multi-Call-Binary-Clone von BusyBox-ähnlichen Multi-Call-Binary in purem Zig 0.16.

## Status-Legende
- ✅ implementiert (grundlegend)
- 🟡 teilweise / unvollständig
- ⬜ geplant
- ❌ bewusst nicht (oder später)

---

## Phase 0 – Fundament (erledigt)
- ✅ Multi-Call-Dispatch (argv[0] / `busybox <cmd>`)
- ✅ Zig-0.16-APIs (`process.Init`, `Io`, `Dir`, `File`)
- ✅ ReleaseSmall-Build (~200 KB)
- ✅ Grundlegende Applets: echo, true/false, cat, ls, pwd, mkdir, rmdir, rm, touch, cp, mv, ln, sleep, yes, head, tail, wc, basename, dirname, uname, whoami, id, date, clear, seq, test/[

## Phase 1 – Robustheit & Core-Utilities (aktuell)
Priorität: die am häufigsten genutzten Tools stabil und nützlicher machen.

| Applet      | Status | Nächste Schritte |
|-------------|--------|------------------|
| echo        | 🟡     | `-e` / `-E`, Escape-Sequenzen |
| cat         | 🟡     | `-n`, `-b`, `-s` |
| ls          | ✅     | `-a -A -l -h -d -F` (kein `-R` noch) |
| rm          | ✅     | `-r`/`-R`, `-f` (kein `-i` noch) |
| cp          | 🟡     | `-r`, `-p`, `-v`, Ziel-Verzeichnis |
| mv          | 🟡     | Ziel-Verzeichnis, `-v` |
| mkdir       | ✅     | `-p` (kein `-m` noch) |
| touch       | 🟡     | mtime-Update, `-c` |
| ln          | 🟡     | `-f` |
| head/tail   | 🟡     | `-c`, `-q`/`-v` |
| wc          | 🟡     | `-l`/`-w`/`-c` Flags |
| test / [    | 🟡     | echte Checks (`-f`,`-d`,`-e`, …) |
| printf      | ✅     | `%s %d %i %u %x %X %c`, `\n \t \r` |
| env / printenv | ✅  | alle / einzelne Variable |
| which / type | ⬜    | neu |
| dirname/basename | ✅ | ggf. Suffix-Support |

**Meilenstein Phase 1:** Alle Core-File-Tools sind alltagstauglich und haben die wichtigsten POSIX/BusyBox-Flags.

## Phase 2 – Text & Suche
| Applet   | Status | Notizen |
|----------|--------|---------|
| grep     | ⬜     | Basis + `-i`, `-v`, `-n`, `-r` |
| sed      | ⬜     | nur einfache s/// |
| cut      | ⬜     | `-d`, `-f`, `-c` |
| sort     | ⬜     | `-n`, `-r`, `-u` |
| uniq     | ⬜     | |
| tr       | ⬜     | |
| rev      | ⬜     | |
| od / hexdump | ⬜ | |

## Phase 3 – System & Prozess
| Applet     | Status | Notizen |
|------------|--------|---------|
| ps         | ⬜     | /proc-basiert |
| kill       | ⬜     | |
| killall    | ⬜     | |
| free       | ⬜     | |
| uptime     | ⬜     | |
| df         | ⬜     | |
| du         | ⬜     | |
| mount/umount | ⬜  | vorsichtig |
| hostname   | ⬜     | |
| uname      | 🟡     | mehr Flags (`-a`, `-s`, …) |
| id/whoami  | 🟡     | echte UID/GID über posix |
| date       | 🟡     | Format-String (`+…`) |

## Phase 4 – Shell & Scripting-Helfer
| Applet    | Status | Notizen |
|-----------|--------|---------|
| sh / ash  | ❌/⬜  | sehr groß – optional später |
| xargs     | ⬜     | |
| find      | ⬜     | Basis + `-name`, `-type` |
| xargs     | ⬜     | |
| expr      | ⬜     | |
| test      | 🟡     | erweitern |
| printf    | ✅     | 
| readlink  | ⬜     | |
| realpath  | ⬜     | |
| mktemp    | ⬜     | |
| install   | ⬜     | |

## Phase 5 – Netzwerk (optional)
| Applet   | Status |
|----------|--------|
| ping     | ⬜     |
| wget/curl| ⬜     |
| nc       | ⬜     |
| ifconfig | ⬜     |
| netstat  | ⬜     |

## Phase 6 – Architektur & Qualität
- ⬜ Applets in eigene Module (`src/applets/*.zig`)
- ⬜ Gemeinsame Hilfsfunktionen (`src/util.zig`: flags, path, print-error)
- ⬜ Einheitliches `--help` pro Applet
- ⬜ Tests (zumindest für reine Funktionen)
- ⬜ `CONFIG_*`-ähnliche Compile-Time-Flags (Feature-Toggle)
- ⬜ Größe weiter optimieren (ReleaseSmall + Strip)
- ⬜ Man-Pages / `busybox --list`
- ⬜ Cross-Compile-Beispiele (musl, aarch64, …)

---

## Nächste konkrete Schritte (Reihenfolge)

1. **Dokumentation & Struktur** ← *gerade*
2. `printf` implementieren
3. `rm -r` / `rm -f`
4. `mkdir -p`
5. Besseres `ls` (`-l`, `-a`)
6. `test`/`[` erweitern
7. `env` / `printenv`
8. `grep` (Basis)
9. Refactoring in Module
10. Weitere Tools nach Bedarf

## Design-Prinzipien
- Kein C-Code, pure Zig
- Kleine Binary-Größe bevorzugen
- POSIX/BusyBox-Verhalten wo sinnvoll und machbar
- Fehlerausgaben im Stil von BusyBox (`applet: msg`)
- Keine externen Dependencies
- Zig-0.16-Io-API konsequent nutzen
