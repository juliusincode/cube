# Architektur

## Überblick

```
argv[0]  ──►  basename  ──►  Applet-Name
                │
                ▼
         cube <cmd> ?  ──►  args[1] als Applet
                │
                ▼
            dispatch()  ──►  cmdXxx()
```

Das Binary ist ein klassischer **Multi-Call-Binary**:

1. Wird es als `busybox` (oder `bb`) aufgerufen, kommt der Applet-Name aus `argv[1]`.
2. Wird es über einen Symlink (`ls` → `busybox`) aufgerufen, ist der Applet-Name der Basename von `argv[0]`.

## Zig 0.16 Einstiegspunkt

```zig
pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const io   = init.io;
    const args = try init.minimal.args.toSlice(arena);
    // ...
}
```

Wichtige Teile von `Init`:

| Feld            | Zweck                              |
|-----------------|-------------------------------------|
| `arena`         | Lifetime = Prozess                  |
| `gpa`           | General-Purpose-Allocator           |
| `io`            | `std.Io` – alle I/O-Operationen     |
| `minimal.args`  | Kommandozeilenargumente             |
| `environ_map`   | Umgebung (für `env`/`printenv`)     |

## I/O-Modell (std.Io)

Ab Zig 0.16 sind Dateisystem- und I/O-Operationen über die `Io`-Schnittstelle abstrahiert:

- `Io.Dir.cwd()` – aktuelles Verzeichnis
- `dir.openFile(io, path, opts)`
- `dir.createFile(io, path, opts)`
- `dir.createDir(io, path, permissions)`
- `Io.File.Reader` / `Io.File.Writer`
- `reader.interface.takeDelimiter('\n')`
- `reader.interface.readSliceShort(buf)`

Alle syscalls laufen über den `Io`-VTable (Threaded, Uring, …).

## Dateistruktur (aktuell)

```
src/
  main.zig          # Dispatch + alle Applets (monolithisch)
docs/
  ARCHITECTURE.md
  APPLETS.md
  CONTRIBUTING.md
ROADMAP.md
README.md
build.zig
```

**Geplant (Phase 6):**

```
src/
  main.zig          # nur Dispatch + main
  util.zig          # gemeinsame Helfer (Flags, Fehler, Pfade)
  applets/
    echo.zig
    cat.zig
    ls.zig
    ...
```

## Fehlerbehandlung

Konvention (BusyBox-ähnlich):

```
applet: dateiname: No such file or directory
```

Exit-Codes:

| Code | Bedeutung                |
|------|--------------------------|
| 0    | Erfolg                   |
| 1    | genereller Fehler        |
| 127  | Applet nicht gefunden    |

## Build-System

`build.zig` erzeugt ein einziges Executable namens `busybox`.  
Keine externen Dependencies.  
`ReleaseSmall` ist der empfohlene Optimierungsmodus für Größe.
