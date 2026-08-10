# Tests

## Zig unit tests

```bash
zig build test
```

## Integration harness

```bash
python3 tests/harness.py
python3 tests/harness.py --cube /path/to/cube -v
```

Environment: `CUBE=/path/to/cube` is also accepted.

The harness creates a private scratch directory, runs applets, and checks
exit codes and output. Exit status is `0` only if every case passes.
