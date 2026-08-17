# Engineering standards

cube aims to become a **production-capable BusyBox alternative** in pure Zig.

## Compatibility

1. Prefer **BusyBox** behaviour when it conflicts with GNU coreutils, unless POSIX mandates otherwise.
2. Document intentional deviations in `docs/APPLETS.md`.
3. Exit codes: `0` success, `1` operational error, `2` usage error where applicable, `127` unknown applet.

## CLI

- Global: `cube --help`, `cube --version`, `cube --list`
- Multi-call via basename of `argv[0]` (`ln -s cube ls`)
- Dispatcher names: `cube`, `busybox`, `bb`
- Errors to stderr: `applet: message` or `applet: path: message`

## Code layout

| Kind | File |
|------|------|
| Text / filters | `src/applets/text.zig` |
| Filesystem | `src/applets/fs.zig` |
| System / process | `src/applets/sys.zig` |
| Shared helpers | `src/util.zig` |

New applets:

1. Implement `pub fn cmdFoo(...)` in its own file, `src/applets/<group>/foo.zig`.
2. Re-export it from `src/applets/<group>.zig` and reference the new file in that same aggregator's `test {}` block (see [ARCHITECTURE.md](ARCHITECTURE.md) — otherwise its unit tests silently never run).
3. In `src/main.zig`, add a thin adapter (`fn hFoo(ctx: Ctx) !void { try module.cmdFoo(...); }`) and one row in `dispatch_table`.
4. Add the name to `src/applets_list.zig` (alphabetical). A comptime check in `main.zig` fails the build if `dispatch_table` and `applets_list.names` diverge in size.
5. Document in `docs/APPLETS.md`.
6. Add a harness case and/or unit test when practical.

## Dependencies and size

- No third-party packages in the default build
- Optimize with `zig build -Doptimize=ReleaseSmall`

## Testing

```bash
zig build test
python3 tests/harness.py --cube zig-out/bin/cube
```
