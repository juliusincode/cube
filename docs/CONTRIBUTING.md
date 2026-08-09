# Adding new applets

## 1. Write the function

In `src/main.zig` (later in `src/applets/xxx.zig`):

```zig
fn cmdPrintf(io: Io, args: []const [:0]const u8) !void {
    // args[0] == "printf"
    // ...
}
```

## 2. Register in the dispatcher

```zig
} else if (mem.eql(u8, applet, "printf")) {
    try cmdPrintf(io, argv);
}
```

## 3. Update help

Extend the applet list in `printUsage()`.

## 4. Update ROADMAP + APPLETS.md

Set status from ⬜ to 🟡/✅ and document flags.

## Tips

- Always use `Io.File.Writer` + `flush` for output.
- Write errors in the style `printf: ...\n` to stderr.
- Use a sensible exit code for missing operands (usually 1).
- Use the arena allocator for temporary allocations.
- No global variables; pass everything as parameters.
- Call `std.process.exit(n)` only when the process must actually terminate.

## Example skeleton

```zig
fn cmdFoo(io: Io, args: []const [:0]const u8) !void {
    if (args.len < 2) {
        try writeAll(io, .stderr(), "foo: missing operand\n");
        std.process.exit(1);
    }
    // ...
}
```
