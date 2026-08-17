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

### Handler table

`dispatch()` resolves the applet name through a `std.StaticStringMap(Handler)`
built at comptime (`dispatch_table` in `main.zig`), not a string-comparison
chain. Each `cmd*` function in `src/applets/*.zig` has its own parameter list
(some need `arena`, some need `environ`, most just need `io` and `argv`), so
every table entry points at a small per-applet adapter that unpacks a shared
`Ctx` and forwards to the real implementation:

```zig
fn hGrep(ctx: Ctx) !void {
    try text.cmdGrep(ctx.io, ctx.arena, ctx.argv);
}
// ...
.{ "grep", hGrep },
```

A comptime check fails the build if `dispatch_table` and
`applets_list.names` ever diverge in length, so the two lists cannot silently
drift apart.

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

### Internal layout: one file per applet

`src/applets/text.zig`, `fs.zig`, and `sys.zig` are the `build.zig` module
boundaries above, but they are not where applet code lives — each is a thin
aggregator that re-exports one `pub const cmdFoo = @import("text/foo.zig").cmdFoo;`
line per applet. The actual implementation of every applet is its own file
under `src/applets/{text,fs,sys}/<applet>.zig`, e.g. `src/applets/text/grep.zig`.

A private helper used by exactly one applet lives in that applet's own file.
A helper shared by two or more applets in the same group (e.g. `hashSum`
between `md5sum`/`sha256sum`, `formatHumanSize` between `df`/`du`/`ls`) lives
in that group's `common.zig` and is imported as `common.<name>`. Sub-files
implicitly see the parent module's named imports (`util`, etc.) — Zig
resolves those against the enclosing `Module`, not the individual file, so no
extra wiring in `build.zig` is needed when adding a new per-applet file.

Because a plain `@import(...).cmdFoo` field access only forces analysis of
that one declaration, each aggregator also carries an explicit
`test { _ = @import("text/foo.zig"); ... }` block referencing every file in
the group. Without it, `zig build test` would silently skip `test` blocks
living in files that are only reached through a re-exported value — add a
new per-applet file and forget this line, and its tests stop running with no
error. Keep new files listed in the aggregator's `test {}` block.

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
