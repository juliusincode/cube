# Adding new applets

## 1. Choose a module

| Kind of applet | File |
|----------------|------|
| Text / filters | `src/applets/text.zig` |
| Filesystem | `src/applets/fs.zig` |
| System / env | `src/applets/sys.zig` |
| Shared helper | `src/util.zig` |

## 2. Write a public function

```zig
pub fn cmdFoo(io: Io, args: []const [:0]const u8) !void {
    // args[0] == "foo"
    // ...
}
```

Use `util.writeAll` for simple stderr/stdout writes.

## 3. Register in the dispatcher

In `src/main.zig`:

```zig
} else if (mem.eql(u8, applet, "foo")) {
    try text.cmdFoo(io, argv); // or fs. / sys.
}
```

## 4. Update help and docs

- Extend the list in `printUsage()` in `main.zig`
- Set status in `ROADMAP.md` and `docs/APPLETS.md`

## Tips

- Always use `Io.File.Writer.initStreaming` for stdout/stderr.
- Write errors as `foo: ...\n` to stderr.
- Use a sensible exit code for missing operands (usually 1).
- Use the arena allocator for temporary allocations.
- No global variables; pass everything as parameters.
- Call `std.process.exit(n)` only when the process must actually terminate.

## Example skeleton

```zig
pub fn cmdFoo(io: Io, args: []const [:0]const u8) !void {
    if (args.len < 2) {
        try util.writeAll(io, .stderr(), "foo: missing operand\n");
        std.process.exit(1);
    }
    // ...
}
```


## Unit tests

Add `test "name" { ... }` blocks in the same file as the code under test.

```zig
test "my helper" {
    try std.testing.expectEqualStrings("x", myHelper("a/x"));
}
```

Run all tests:

```bash
zig build test
```


## Integration tests

```bash
zig build -Doptimize=ReleaseSmall
python3 tests/harness.py --cube zig-out/bin/cube
```

`tests/harness.py` exercises globals and major applets in a temporary
directory (exit codes, stdout, side effects). Extend it when adding applets.
