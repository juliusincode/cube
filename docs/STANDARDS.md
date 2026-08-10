# Engineering standards

cube aims to become a **production-capable BusyBox alternative** in pure Zig.
These conventions keep behaviour predictable and the codebase maintainable.

## Compatibility

1. Prefer **BusyBox** behaviour when it conflicts with GNU coreutils, unless
   POSIX mandates otherwise.
2. Document intentional deviations in `docs/APPLETS.md`.
3. Exit codes: `0` success, `1` operational error, `2` usage error where
   applicable, `127` unknown applet.

## CLI conventions

- Global: `cube --help`, `cube --version`, `cube --list`
- Multi-call: basename of `argv[0]` selects the applet (`ln -s cube ls`)
- Dispatcher names: `cube`, `busybox`, `bb`
- Errors to stderr: `applet: message` or `applet: path: message`
- No interactive prompts in default mode (no `rm -i` unless explicitly added)

## Code layout

| Path | Responsibility |
|------|----------------|
| `src/main.zig` | Entry, dispatch, global flags |
| `src/util.zig` | Shared I/O helpers |
| `src/version.zig` | Semver constants |
| `src/applets_list.zig` | Canonical name list |
| `src/applets/text.zig` | Text / filters |
| `src/applets/fs.zig` | Filesystem |
| `src/applets/sys.zig` | Process / system |

New applets:

1. Implement `pub fn cmdFoo(...)` in the right module
2. Register in `main.zig` dispatch
3. Add the name to `applets_list.zig` (alphabetical)
4. Document flags in `docs/APPLETS.md`
5. Add unit tests for pure helpers when practical

## I/O (Zig 0.16)

- Always pass `io: std.Io` through
- Use `initStreaming` for stdout/stderr writers
- Prefer arena for short-lived allocations tied to the process

## Size and dependencies

- No libc requirement beyond what Zig’s linux target already uses
- No third-party packages in the default build
- Optimize with `zig build -Doptimize=ReleaseSmall`

## Testing

```bash
zig build test
```

Integration checks: run applets against known inputs in a scratch directory.
