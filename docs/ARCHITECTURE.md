# Architecture

## Multi-call dispatch

```
argv[0]  →  basename  →  applet name
                │
                ▼
     name is cube/busybox/bb ?
                │
        yes     │     no
         ▼      │      ▼
   argv[1] =    │   basename(argv[0])
   applet       │   = applet
                ▼
           dispatch() → applets.*.cmdXxx()
```

Symlink example: `ls` → `cube` → applet `ls`.

## Zig 0.16 entry

```zig
pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const io   = init.io;
    const args = try init.minimal.args.toSlice(arena);
    // ...
}
```

| `Init` field      | Role |
|-------------------|------|
| `arena`           | Process-lifetime allocator |
| `io`              | `std.Io` for all I/O |
| `minimal.args`    | argv |
| `environ_map`     | Environment (`env` / `which`) |

## Modules (`build.zig`)

Named imports:

| Name | Source |
|------|--------|
| `util` | `src/util.zig` |
| `text` | `src/applets/text.zig` |
| `fs`   | `src/applets/fs.zig` |
| `sys`  | `src/applets/sys.zig` |
| `version` | `src/version.zig` |
| `applets_list` | `src/applets_list.zig` |

`main.zig` imports all four. Applets import `util` only.

## I/O notes

- Prefer `Io.File.Writer.initStreaming` for **stdout/stderr** (positional mode overwrites from offset 0).
- Filesystem calls go through `Io.Dir` / `Io.File` with the `io` handle.
- Symlink-aware tools (`find -type l`, `readlink`) use `follow_symlinks = false` where needed.

## Error style

```
applet: path: Message
```

| Exit | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 127 | Unknown applet |

## Tests

```bash
zig build test
```

`test "…"` blocks live next to the code (`util`, `text`, `fs`, `main`).
