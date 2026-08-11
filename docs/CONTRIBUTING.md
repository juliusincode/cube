# Contributing

## Development setup

```bash
# Zig 0.16+
zig build -Doptimize=Debug
zig build test
python3 tests/harness.py --cube zig-out/bin/cube
```

## Adding an applet

1. Choose module: `text` / `fs` / `sys` (see [STANDARDS.md](STANDARDS.md)).
2. Implement `pub fn cmdFoo(io: Io, …) !void`.
3. Wire the branch in `src/main.zig`.
4. Insert the name alphabetically in `src/applets_list.zig`.
5. Update `docs/APPLETS.md` and the help text in `main.zig` if needed.
6. Prefer a case in `tests/harness.py`.

### Skeleton

```zig
pub fn cmdFoo(io: Io, args: []const [:0]const u8) !void {
    // args[0] == "foo"
    _ = args;
    try util.writeAll(io, .stdout(), "ok\n");
}
```

## Commit style

Prefer conventional prefixes: `feat:`, `fix:`, `docs:`, `test:`, `refactor:`.

## License

By contributing, you agree that your contributions are licensed under the MIT License.
