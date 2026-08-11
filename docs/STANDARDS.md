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

1. Implement `pub fn cmdFoo(...)`
2. Register in `src/main.zig` dispatch
3. Add the name to `src/applets_list.zig` (alphabetical)
4. Document in `docs/APPLETS.md`
5. Add a harness case and/or unit test when practical

## Dependencies and size

- No third-party packages in the default build
- Optimize with `zig build -Doptimize=ReleaseSmall`

## Testing

```bash
zig build test
python3 tests/harness.py --cube zig-out/bin/cube
```
