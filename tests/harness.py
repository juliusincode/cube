#!/usr/bin/env python3
"""
cube integration test harness.

Runs the multi-call binary against a private scratch directory and checks
exit codes, stdout, and basic behavioural contracts for each applet.

Usage:
  python3 tests/harness.py
  python3 tests/harness.py --cube /path/to/cube
  CUBE=/path/to/cube python3 tests/harness.py -v
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, Optional


# ---------------------------------------------------------------------------
# Result tracking
# ---------------------------------------------------------------------------

@dataclass
class CaseResult:
    name: str
    ok: bool
    detail: str = ""


@dataclass
class Suite:
    results: list[CaseResult] = field(default_factory=list)

    def check(self, name: str, ok: bool, detail: str = "") -> None:
        self.results.append(CaseResult(name, ok, detail))
        mark = "PASS" if ok else "FAIL"
        line = f"  [{mark}] {name}"
        if detail and (not ok or VERBOSE):
            line += f" — {detail}"
        print(line)

    def expect(
        self,
        name: str,
        cond: bool,
        detail: str = "",
    ) -> None:
        self.check(name, cond, detail)

    @property
    def failed(self) -> list[CaseResult]:
        return [r for r in self.results if not r.ok]

    @property
    def passed(self) -> int:
        return sum(1 for r in self.results if r.ok)


VERBOSE = False


# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------

class Cube:
    def __init__(self, binary: Path, work: Path):
        self.binary = binary
        self.work = work

    def run(
        self,
        *argv: str,
        stdin: Optional[str | bytes] = None,
        timeout: float = 10.0,
        env: Optional[dict] = None,
    ) -> subprocess.CompletedProcess:
        cmd = [str(self.binary), *argv]
        input_data: Optional[bytes]
        if stdin is None:
            input_data = None
        elif isinstance(stdin, bytes):
            input_data = stdin
        else:
            input_data = stdin.encode()

        full_env = os.environ.copy()
        if env:
            full_env.update(env)

        return subprocess.run(
            cmd,
            input=input_data,
            capture_output=True,
            timeout=timeout,
            cwd=str(self.work),
            env=full_env,
        )

    def out(self, *argv: str, **kw) -> str:
        p = self.run(*argv, **kw)
        return p.stdout.decode(errors="replace")

    def err(self, *argv: str, **kw) -> str:
        p = self.run(*argv, **kw)
        return p.stderr.decode(errors="replace")


# ---------------------------------------------------------------------------
# Tests: global CLI
# ---------------------------------------------------------------------------

def test_globals(c: Cube, s: Suite) -> None:
    p = c.run("--version")
    s.expect(
        "global --version exit 0",
        p.returncode == 0,
        f"rc={p.returncode}",
    )
    s.expect(
        "global --version banner",
        b"cube" in p.stdout.lower() and b"0." in p.stdout,
        p.stdout.decode(errors="replace").strip(),
    )

    p = c.run("-V")
    s.expect("global -V exit 0", p.returncode == 0)

    p = c.run("--help")
    s.expect("global --help exit 0", p.returncode == 0)
    s.expect(
        "global --help mentions Usage",
        b"Usage" in p.stdout or b"usage" in p.stdout.lower(),
    )

    p = c.run("--list")
    s.expect("global --list exit 0", p.returncode == 0)
    names = [ln for ln in p.stdout.decode().splitlines() if ln.strip()]
    s.expect("global --list non-empty", len(names) >= 40, f"count={len(names)}")
    for required in ("echo", "ls", "cat", "grep", "ps", "true", "false"):
        s.expect(f"global --list contains {required}", required in names)

    p = c.run("not_an_applet_xyz")
    s.expect("unknown applet exit 127", p.returncode == 127, f"rc={p.returncode}")


# ---------------------------------------------------------------------------
# Tests: trivial / logic
# ---------------------------------------------------------------------------

def test_logic(c: Cube, s: Suite) -> None:
    p = c.run("true")
    s.expect("true exit 0", p.returncode == 0)

    p = c.run("false")
    s.expect("false exit non-zero", p.returncode != 0)

    p = c.run("echo", "hello", "world")
    s.expect("echo text", p.stdout == b"hello world\n", repr(p.stdout))

    p = c.run("echo", "-n", "x")
    s.expect("echo -n no newline", p.stdout == b"x", repr(p.stdout))

    p = c.run("printf", "%s-%d\\n", "a", "3")
    s.expect("printf basic", b"a-3" in p.stdout, repr(p.stdout))


# ---------------------------------------------------------------------------
# Tests: filesystem
# ---------------------------------------------------------------------------

def test_fs(c: Cube, s: Suite) -> None:
    # mkdir / touch / ls
    p = c.run("mkdir", "d1")
    s.expect("mkdir d1", p.returncode == 0 and (c.work / "d1").is_dir())

    p = c.run("touch", "d1/a.txt")
    s.expect("touch file", p.returncode == 0 and (c.work / "d1/a.txt").is_file())

    (c.work / "d1/a.txt").write_text("alpha\n")

    p = c.run("ls", "d1")
    s.expect("ls lists a.txt", b"a.txt" in p.stdout, repr(p.stdout))

    p = c.run("ls", "-l", "d1")
    s.expect("ls -l long format", p.returncode == 0 and len(p.stdout) > 0)

    p = c.run("cat", "d1/a.txt")
    s.expect("cat content", p.stdout == b"alpha\n", repr(p.stdout))

    p = c.run("cp", "d1/a.txt", "d1/b.txt")
    s.expect("cp creates b.txt", p.returncode == 0 and (c.work / "d1/b.txt").is_file())
    s.expect("cp content match", (c.work / "d1/b.txt").read_text() == "alpha\n")

    p = c.run("mv", "d1/b.txt", "d1/c.txt")
    s.expect(
        "mv renames",
        p.returncode == 0
        and (c.work / "d1/c.txt").is_file()
        and not (c.work / "d1/b.txt").exists(),
    )

    p = c.run("rm", "d1/c.txt")
    s.expect("rm file", p.returncode == 0 and not (c.work / "d1/c.txt").exists())

    p = c.run("mkdir", "-p", "d2/nested/deep")
    s.expect("mkdir -p", p.returncode == 0 and (c.work / "d2/nested/deep").is_dir())

    p = c.run("pwd")
    s.expect("pwd exit 0", p.returncode == 0)
    s.expect("pwd absolute", p.stdout.decode().strip().startswith("/"))

    p = c.run("basename", "/tmp/foo/bar.txt")
    s.expect("basename", p.stdout.strip() == b"bar.txt", repr(p.stdout))

    p = c.run("dirname", "/tmp/foo/bar.txt")
    s.expect("dirname", p.stdout.strip() == b"/tmp/foo", repr(p.stdout))

    p = c.run("realpath", ".")
    s.expect("realpath .", p.returncode == 0 and p.stdout.startswith(b"/"))

    p = c.run("mktemp", str(c.work / "tmp.XXXXXX"))
    path = p.stdout.decode().strip()
    s.expect("mktemp exit 0", p.returncode == 0)
    s.expect("mktemp creates file", Path(path).is_file() if path else False, path)

    p = c.run("du", "-s", "d1")
    s.expect("du -s", p.returncode == 0 and len(p.stdout) > 0)

    # find
    p = c.run("find", "d1", "-name", "*.txt")
    s.expect("find -name", p.returncode == 0 and b"a.txt" in p.stdout, repr(p.stdout))

    p = c.run("find", "d1", "-type", "f")
    s.expect("find -type f", p.returncode == 0 and b"a.txt" in p.stdout)

    # ln symlink + readlink
    p = c.run("ln", "-s", "a.txt", "d1/link.txt")
    s.expect("ln -s", p.returncode == 0)
    p = c.run("readlink", "d1/link.txt")
    s.expect("readlink", b"a.txt" in p.stdout, repr(p.stdout))

    # cleanup leaf dirs
    p = c.run("rmdir", "d2/nested/deep")
    s.expect("rmdir", p.returncode == 0)


# ---------------------------------------------------------------------------
# Tests: text tools
# ---------------------------------------------------------------------------

def test_text(c: Cube, s: Suite) -> None:
    sample = c.work / "sample.txt"
    sample.write_text("foo\nbar\nfoo\nbaz\n")

    p = c.run("wc", "-l", "sample.txt")
    s.expect("wc -l", b"4" in p.stdout, repr(p.stdout))

    p = c.run("head", "-n", "2", "sample.txt")
    s.expect("head -n 2", p.stdout == b"foo\nbar\n", repr(p.stdout))

    p = c.run("tail", "-n", "1", "sample.txt")
    s.expect("tail -n 1", p.stdout == b"baz\n", repr(p.stdout))

    p = c.run("grep", "foo", "sample.txt")
    s.expect("grep match", p.stdout.count(b"foo") == 2, repr(p.stdout))

    p = c.run("grep", "-c", "foo", "sample.txt")
    s.expect("grep -c", b"2" in p.stdout, repr(p.stdout))

    p = c.run("grep", "-v", "foo", "sample.txt")
    s.expect("grep -v", b"bar" in p.stdout and b"foo" not in p.stdout)

    p = c.run("sort", "sample.txt")
    s.expect(
        "sort",
        p.stdout == b"bar\nbaz\nfoo\nfoo\n",
        repr(p.stdout),
    )

    p = c.run("sort", "-u", "sample.txt")
    s.expect("sort -u", p.stdout == b"bar\nbaz\nfoo\n", repr(p.stdout))

    p = c.run("uniq", stdin="a\na\nb\n")
    s.expect("uniq", p.stdout == b"a\nb\n", repr(p.stdout))

    p = c.run("cut", "-d", ":", "-f", "2", stdin="a:b:c\n")
    s.expect("cut -f2", p.stdout.strip() == b"b", repr(p.stdout))

    p = c.run("tr", "a-z", "A-Z", stdin="ab\n")
    s.expect("tr upper", p.stdout == b"AB\n", repr(p.stdout))

    p = c.run("rev", stdin="abc\n")
    s.expect("rev", p.stdout == b"cba\n", repr(p.stdout))

    p = c.run("sed", "s/foo/X/g", "sample.txt")
    s.expect("sed global", b"X" in p.stdout and b"foo" not in p.stdout, repr(p.stdout))

    p = c.run("tee", "tee_out.txt", stdin="tee-data\n")
    s.expect("tee stdout", p.stdout == b"tee-data\n", repr(p.stdout))
    s.expect(
        "tee file",
        (c.work / "tee_out.txt").read_text() == "tee-data\n",
    )

    p = c.run("xargs", "echo", stdin="one\ntwo\n")
    s.expect("xargs echo", b"one" in p.stdout and b"two" in p.stdout, repr(p.stdout))

    p = c.run("base64", "-w", "0", stdin="hello")
    s.expect("base64 encode", b"aGVsbG8=" in p.stdout, repr(p.stdout))
    p = c.run("base64", "-d", stdin="aGVsbG8=")
    s.expect("base64 decode", p.stdout == b"hello", repr(p.stdout))

    p = c.run("md5sum", stdin="hello")
    s.expect("md5sum hello", b"5d41402abc4b2a76b9719d911017c592" in p.stdout, repr(p.stdout))

    p = c.run("sha256sum", stdin="hello")
    s.expect(
        "sha256sum hello",
        b"2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824" in p.stdout,
        repr(p.stdout),
    )

    (c.work / "cmp_a").write_text("same\n")
    (c.work / "cmp_b").write_text("same\n")
    (c.work / "cmp_c").write_text("diff\n")
    p = c.run("cmp", "cmp_a", "cmp_b")
    s.expect("cmp equal", p.returncode == 0)
    p = c.run("cmp", "-s", "cmp_a", "cmp_c")
    s.expect("cmp differ silent", p.returncode == 1)

    p = c.run("nproc")
    s.expect("nproc", p.returncode == 0 and p.stdout.strip().isdigit(), repr(p.stdout))

    p = c.run("od", "-A", "n", "-N", "4", stdin="abcd")
    s.expect("od bytes", b"61" in p.stdout and b"62" in p.stdout, repr(p.stdout))

    (c.work / "chmod_f").write_text("x")
    p = c.run("chmod", "600", "chmod_f")
    s.expect("chmod", p.returncode == 0)

    p = c.run("sync")
    s.expect("sync", p.returncode == 0)
    p = c.run("nl", stdin="a\nb\n")
    s.expect("nl numbers", b"1" in p.stdout and b"a" in p.stdout, repr(p.stdout))

    p = c.run("tac", stdin="1\n2\n3\n")
    s.expect("tac reverse", p.stdout == b"3\n2\n1\n", repr(p.stdout))

    p = c.run("strings", "-n", "4", stdin=b"xx\x00ABCD\x00yy")
    s.expect("strings", b"ABCD" in p.stdout, repr(p.stdout))

    p = c.run("fold", "-w", "4", stdin="abcdefgh")
    s.expect("fold", b"abcd" in p.stdout and b"efgh" in p.stdout, repr(p.stdout))
    (c.work / "pa").write_text("a\nb\n")
    (c.work / "pb").write_text("1\n2\n")
    p = c.run("paste", "pa", "pb")
    s.expect("paste", b"a" in p.stdout and b"1" in p.stdout, repr(p.stdout))

    p = c.run("expand", "-t", "4", stdin="a\tb\n")
    s.expect("expand", b"a" in p.stdout and b"\t" not in p.stdout, repr(p.stdout))

    p = c.run("factor", "12")
    s.expect("factor 12", b"2" in p.stdout and b"3" in p.stdout, repr(p.stdout))

    p = c.run("truncate", "-s", "8", "trunc_f")
    s.expect("truncate", p.returncode == 0 and (c.work / "trunc_f").stat().st_size == 8)
    p = c.run("expr", "3", "+", "4")
    s.expect("expr add", b"7" in p.stdout, repr(p.stdout))

    p = c.run("expr", "length", "abcd")
    s.expect("expr length", b"4" in p.stdout, repr(p.stdout))

    p = c.run("shuf", "-i", "1-3")
    s.expect("shuf range", p.returncode == 0 and len(p.stdout.splitlines()) == 3)

    (c.work / "split_in").write_text("1\n2\n3\n4\n")
    p = c.run("split", "-l", "2", "split_in", "sp")
    s.expect("split", p.returncode == 0 and (c.work / "spaa").is_file())

    (c.work / "ul").write_text("x")
    p = c.run("unlink", "ul")
    s.expect("unlink", p.returncode == 0 and not (c.work / "ul").exists())
    (c.work / "j1").write_text("a 1\nb 2\n")
    (c.work / "j2").write_text("a x\nb y\n")
    p = c.run("join", "j1", "j2")
    s.expect("join keys", b"a" in p.stdout and b"1" in p.stdout and b"x" in p.stdout, repr(p.stdout))

    (c.work / "c1").write_text("a\nb\n")
    (c.work / "c2").write_text("b\nc\n")
    p = c.run("comm", "c1", "c2")
    s.expect("comm", p.returncode == 0 and b"b" in p.stdout, repr(p.stdout))

    p = c.run("fmt", "-w", "20", stdin="one two three four five six")
    s.expect("fmt", p.returncode == 0 and len(p.stdout) > 0)

    p = c.run("arch")
    s.expect("arch", p.returncode == 0 and len(p.stdout.strip()) > 0)





    p = c.run("seq", "1", "3")
    s.expect("seq", p.stdout == b"1\n2\n3\n", repr(p.stdout))

    # yes is intentionally infinite — covered by a short timed run below
    try:
        p = c.run("yes", timeout=0.3)
        s.expect("yes produces output", False, "should have timed out")
    except subprocess.TimeoutExpired as e:
        out = e.stdout or b""
        s.expect("yes streams y", b"y" in out, f"stdout_len={len(out)}")

    p = c.run("test", "-f", "sample.txt")
    s.expect("test -f true", p.returncode == 0)

    p = c.run("test", "-f", "no_such_file")
    s.expect("test -f false", p.returncode != 0)

    p = c.run("[", "-d", "d1", "]")
    s.expect("[ -d d1 ]", p.returncode == 0)


# ---------------------------------------------------------------------------
# Tests: system
# ---------------------------------------------------------------------------

def test_sys(c: Cube, s: Suite) -> None:
    p = c.run("uname")
    s.expect("uname", p.returncode == 0 and len(p.stdout) > 0)

    p = c.run("uname", "-a")
    s.expect("uname -a", p.returncode == 0 and len(p.stdout) > 5)

    p = c.run("hostname")
    s.expect("hostname", p.returncode == 0)

    p = c.run("whoami")
    s.expect("whoami", p.returncode == 0)

    p = c.run("id")
    s.expect("id", p.returncode == 0 and b"uid=" in p.stdout)

    p = c.run("date")
    s.expect("date", p.returncode == 0 and len(p.stdout) > 0)

    p = c.run("date", "+%Y")
    s.expect("date +%Y", re.match(rb"^\d{4}\n$", p.stdout) is not None, repr(p.stdout))

    p = c.run("uptime")
    s.expect("uptime", p.returncode == 0 and (b"load" in p.stdout.lower() or b"up" in p.stdout))

    p = c.run("free")
    s.expect("free", p.returncode == 0 and b"Mem" in p.stdout)

    p = c.run("df")
    s.expect("df", p.returncode == 0 and len(p.stdout) > 0)

    p = c.run("ps")
    s.expect("ps header", p.returncode == 0 and b"PID" in p.stdout)
    s.expect("ps lists self-ish", b"COMMAND" in p.stdout or b"cube" in p.stdout.lower() or len(p.stdout.splitlines()) > 2)

    p = c.run("env")
    s.expect("env", p.returncode == 0 and len(p.stdout) > 0)

    p = c.run("printenv", "PATH")
    s.expect("printenv PATH", p.returncode == 0)

    p = c.run("which", "sh")
    s.expect("which sh", p.returncode == 0 and b"sh" in p.stdout)

    p = c.run("sleep", "0")
    s.expect("sleep 0", p.returncode == 0)

    p = c.run("kill", "-l")
    s.expect("kill -l", p.returncode == 0 and b"TERM" in p.stdout)

    p = c.run("kill", "-0", str(os.getpid()))
    s.expect("kill -0 self", p.returncode == 0)

    p = c.run("kill", "-0", "999999")
    s.expect("kill -0 missing", p.returncode != 0)


# ---------------------------------------------------------------------------
# Discovery
# ---------------------------------------------------------------------------

def find_cube(explicit: Optional[str]) -> Path:
    candidates: list[Path] = []
    if explicit:
        candidates.append(Path(explicit))
    if os.environ.get("CUBE"):
        candidates.append(Path(os.environ["CUBE"]))
    here = Path(__file__).resolve().parent
    root = here.parent
    candidates.extend(
        [
            root / "zig-out" / "bin" / "cube",
            Path("/tmp/cube-out/bin/cube"),
            Path("/tmp/cube"),
        ]
    )
    for c in candidates:
        if c.is_file() and os.access(c, os.X_OK):
            return c.resolve()
    raise SystemExit(
        "cube binary not found. Build with `zig build` or pass --cube /path/to/cube"
    )


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> int:
    global VERBOSE
    ap = argparse.ArgumentParser(description="cube applet integration harness")
    ap.add_argument("--cube", help="path to cube binary")
    ap.add_argument("-v", "--verbose", action="store_true")
    args = ap.parse_args()
    VERBOSE = args.verbose

    binary = find_cube(args.cube)
    print(f"cube: {binary}")

    suite = Suite()
    with tempfile.TemporaryDirectory(prefix="cube-test-") as tmp:
        work = Path(tmp)
        cube = Cube(binary, work)
        print("\n== global ==")
        test_globals(cube, suite)
        print("\n== logic ==")
        test_logic(cube, suite)
        print("\n== filesystem ==")
        test_fs(cube, suite)
        print("\n== text ==")
        test_text(cube, suite)
        print("\n== system ==")
        test_sys(cube, suite)

    print("\n" + "=" * 50)
    print(f"Results: {suite.passed} passed, {len(suite.failed)} failed, {len(suite.results)} total")
    if suite.failed:
        print("\nFailures:")
        for r in suite.failed:
            print(f"  - {r.name}: {r.detail}")
        return 1
    print("All checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
