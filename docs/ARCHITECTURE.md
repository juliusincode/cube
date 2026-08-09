# Architecture

## Overview

```
argv[0]  ──►  basename  ──►  applet name
                │
                ▼
         cube <cmd> ?  ──►  args[1] as applet
                │
                ▼
            dispatch()  ──►  cmdXxx()
```

The binary is a classic **multi-call binary**:

1. When invoked as `cube` (or `busybox` / `bb`), the applet name comes from `argv[1]`.
2. When invoked via a symlink (`ls` → `cube`), the applet name is the basename of `argv[0]`.

## Zig 0.16 entry point

```zig
pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const io   = init.io;
    const args = try init.minimal.args.toSlice(arena);
    // ...
}
```

Important fields of `Init`:

| Field           | Purpose                              |
|-----------------|--------------------------------------|
| `arena`         | Lifetime = process                   |
| `gpa`           | General-purpose allocator            |
| `io`            | `std.Io` – all I/O operations        |
| `minimal.args`  | Command-line arguments               |
| `environ_map`   | Environment (for `env` / `printenv`) |

## I/O model (`std.Io`)

As of Zig 0.16, filesystem and I/O operations go through the `Io` interface:

- `Io.Dir.cwd()` – current directory
- `dir.openFile(io, path, opts)`
- `dir.createFile(io, path, opts)`
- `dir.createDir(io, path, permissions)`
- `Io.File.Reader` / `Io.File.Writer`
- `reader.interface.takeDelimiter('\n')`
- `reader.interface.readSliceShort(buf)`

All syscalls run through the `Io` vtable (Threaded, Uring, …).

## Layout (current)

```
src/
  main.zig          # dispatch + all applets (monolithic)
docs/
  ARCHITECTURE.md
  APPLETS.md
  CONTRIBUTING.md
ROADMAP.md
README.md
build.zig
```

**Planned (Phase 6):**

```
src/
  main.zig          # dispatch + main only
  util.zig          # shared helpers (flags, errors, paths)
  applets/
    echo.zig
    cat.zig
    ls.zig
    ...
```

## Error handling

Convention (BusyBox-like):

```
applet: filename: No such file or directory
```

Exit codes:

| Code | Meaning              |
|------|----------------------|
| 0    | Success              |
| 1    | General error        |
| 127  | Applet not found     |

## Build system

`build.zig` produces a single executable named `cube`.  
No external dependencies.  
`ReleaseSmall` is the recommended optimization mode for size.
