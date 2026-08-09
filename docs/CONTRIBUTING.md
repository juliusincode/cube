# Neue Applets hinzufügen

## 1. Funktion schreiben

In `src/main.zig` (später in `src/applets/xxx.zig`):

```zig
fn cmdPrintf(io: Io, args: []const [:0]const u8) !void {
    // args[0] == "printf"
    // ...
}
```

## 2. In den Dispatch eintragen

```zig
} else if (mem.eql(u8, applet, "printf")) {
    try cmdPrintf(io, argv);
}
```

## 3. Hilfe aktualisieren

In `printUsage()` die Liste der verfügbaren Applets erweitern.

## 4. ROADMAP + APPLETS.md anpassen

Status von ⬜ auf 🟡/✅ setzen und Flags dokumentieren.

## Tipps

- Für Ausgaben immer `Io.File.Writer` + `flush` verwenden.
- Fehler im Stil `printf: ...\n` auf stderr schreiben.
- Bei fehlenden Operanden sinnvollen Exit-Code (meist 1).
- Arena-Allocator für temporäre Allokationen nutzen.
- Keine globalen Variablen; alles über Parameter.
- `std.process.exit(n)` nur wenn der Prozess wirklich beendet werden soll.

## Beispiel-Skelett

```zig
fn cmdFoo(io: Io, args: []const [:0]const u8) !void {
    if (args.len < 2) {
        try writeAll(io, .stderr(), "foo: missing operand\n");
        std.process.exit(1);
    }
    // ...
}
```
