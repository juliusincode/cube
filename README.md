# cube

**cube** is a minimal, educational multi-call binary in pure **Zig 0.16**
(BusyBox-style): one executable, many Unix utilities.

```bash
./cube ls -l
./cube echo hello
ln -s cube cat && ./cat file.txt
```

## Quick start

```bash
# Requires Zig 0.16+
zig build -Doptimize=ReleaseSmall

./zig-out/bin/cube
./zig-out/bin/cube --help
./zig-out/bin/cube echo "hello from cube"
```

## Documentation

| File | Description |
|------|-------------|
| [ROADMAP.md](ROADMAP.md) | Phases, status, planned applets |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Dispatch, Zig 0.16 Io API |
| [docs/APPLETS.md](docs/APPLETS.md) | Applet list and flags |
| [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) | How to add applets |

## Implemented applets

```
echo  true  false  cat  ls  pwd  mkdir  rmdir  rm  touch
cp  mv  ln  sleep  yes  head  tail  wc  basename  dirname
uname  whoami  id  date  clear  seq  test  [  printf  env
printenv
```

## Build options

```bash
zig build -Doptimize=ReleaseSmall   # smallest binary (default goal)
zig build -Doptimize=ReleaseFast
zig build -Doptimize=Debug
zig build run -- echo hello
```

## Design goals

- Pure Zig 0.16 (no C dependencies)
- Small binary size
- Readable, educational code
- BusyBox/POSIX-like behaviour where practical
- Easy to extend

## License

MIT – see [LICENSE](LICENSE)
