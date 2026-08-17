# Contributing

## Development setup

```bash
# Zig 0.16+
zig build -Doptimize=Debug
zig build test
python3 tests/harness.py --cube zig-out/bin/cube
```

## Adding an applet

1. Choose group: `text` / `fs` / `sys` (see [STANDARDS.md](STANDARDS.md)).
2. Create `src/applets/<group>/foo.zig` with `pub fn cmdFoo(io: Io, …) !void`.
   If it needs a helper shared with another applet, put the helper in
   `src/applets/<group>/common.zig` instead of duplicating it.
3. Add one line to `src/applets/<group>.zig`:
   `pub const cmdFoo = @import("<group>/foo.zig").cmdFoo;`
   — and add `_ = @import("<group>/foo.zig");` to that same file's `test {}`
   block, or its unit tests will silently never run (see
   [ARCHITECTURE.md](ARCHITECTURE.md)).
4. In `src/main.zig`, add an adapter (`fn hFoo(ctx: Ctx) !void { … }`) and a row in `dispatch_table`.
5. Insert the name alphabetically in `src/applets_list.zig`.
6. Update `docs/APPLETS.md` and the help text in `main.zig` if needed.
7. Prefer a case in `tests/harness.py`.

### Skeleton

```zig
// src/applets/text/foo.zig
const std = @import("std");
const Io = std.Io;
const util = @import("util");

pub fn cmdFoo(io: Io, args: []const [:0]const u8) !void {
    // args[0] == "foo"
    _ = args;
    try util.writeAll(io, .stdout(), "ok\n");
}
```

```zig
// src/applets/text.zig
pub const cmdFoo = @import("text/foo.zig").cmdFoo;
// ...and in this file's test {} block:
_ = @import("text/foo.zig");
```

```zig
// src/main.zig
fn hFoo(ctx: Ctx) !void {
    try text.cmdFoo(ctx.io, ctx.argv);
}
// ...and in dispatch_table:
.{ "foo", hFoo },
```

## Commit style

Prefer conventional prefixes: `feat:`, `fix:`, `docs:`, `test:`, `refactor:`.

## License

By contributing, you agree that your contributions are licensed under the MIT License.
