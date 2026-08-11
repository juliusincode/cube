# Architecture

## Multi-call dispatch

```text
argv[0]  →  basename  →  name
                │
     name ∈ {cube, busybox, bb} ?
           yes │ no
               │  └── applet = basename(argv[0])
               └── applet = argv[1] (or help if missing)
                          │
                          ▼
                    dispatch(applet)
                          │
          ┌───────────────┼───────────────┐
          ▼               ▼               ▼
       text.cmd*       fs.cmd*        sys.cmd*
```

Symlink example: `ls` → `cube` → applet `ls`.

## Entry (Zig 0.16)

```zig
pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const io = init.io;
    // args, environ from init
}
```

| Field | Role |
|-------|------|
| `arena` | Process-lifetime allocator |
| `io` | `std.Io` for all I/O |
| args | argv |
| environ | environment map |

## Modules (`build.zig`)

| Import name | Source |
|-------------|--------|
| `util` | `src/util.zig` |
| `text` | `src/applets/text.zig` |
| `fs` | `src/applets/fs.zig` |
| `sys` | `src/applets/sys.zig` |
| `version` | `src/version.zig` |
| `applets_list` | `src/applets_list.zig` |

`main.zig` imports all of the above. Applet modules import `util` only.

## I/O conventions

- Prefer `Io.File.Writer.initStreaming` for stdout/stderr (positional writers restart at offset 0).
- Pass `io: std.Io` through every operation.
- Symlink-aware tools use `follow_symlinks = false` where required (`find -type l`, …).

## Errors

```text
applet: path: Message
```

Unknown applet → stderr + exit **127**.

## Tests

- Unit: `test` blocks next to helpers; `zig build test`
- Integration: `tests/harness.py` against a built binary
