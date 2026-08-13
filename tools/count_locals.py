#!/usr/bin/env python3
"""Audit Lua 5.1 per-function local variable and upvalue headroom.

Lua 5.1 enforces two hard per-function limits (see CONTRIBUTING.md):

  * 200 local variables -- parameters and loop variables count too.
  * 60 upvalues         -- variables captured from an enclosing scope.

Both are compile-time failures, so a file that crosses either limit simply
stops loading in-engine. This script reports how close each function is
*before* that happens, while restructuring is still cheap.

Counts come from the reference compiler (``luac5.1 -p -l -l``) rather than a
hand-rolled parser, so they match what the engine's Lua actually sees.

A note on the metric, because the obvious number is the wrong one: the limit
applies to locals that are *simultaneously in scope*, not to how many are
declared. 300 locals in disjoint ``do ... end`` blocks compile fine and report
"300 locals, 3 slots". So this script measures ``slots`` (the compiler's
register high-water mark), which is an upper bound on simultaneously active
locals. Declared totals are shown alongside for context only.

Because ``slots`` also counts temporaries, a healthy function can report a
little over 200 slots without breaching anything -- treat it as pressure, not
as a failure. An actual local-variable breach is a compile error, which this
script reports as LIMIT. Upvalue counts, by contrast, are exact.

Usage:
    tools/count_locals.py                     # audit the whole repository
    tools/count_locals.py luaui/Widgets       # audit a directory
    tools/count_locals.py path/to/file.lua    # audit a single file
    tools/count_locals.py --top 20            # show the 20 tightest functions
    tools/count_locals.py --json              # machine-readable output

Exit status is 1 when a function is at a hard limit or a file fails to
compile, otherwise 0.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from dataclasses import asdict, dataclass
from pathlib import Path

# Lua 5.1 hard limits (LUAI_MAXVARS / LUAI_MAXUPVALUES in luaconf.h).
LOCAL_LIMIT = 200
UPVALUE_LIMIT = 60

# Paths that are not standalone Lua and would only produce noise. Mirrors the
# spirit of .luacheckrc's exclude_files and .styluaignore.
DEFAULT_EXCLUDES = (
    ".git",
    ".lux",
    "common/luaUtilities",
    "mapgenerator",  # ${PLACEHOLDER} templates, not valid Lua on their own
    "recoil-lua-library",
)

# Function headers in the listing look like:
#   main <file.lua:0,0> (15 instructions, 60 bytes at 0x...)
#   function <file.lua:14,22> (10 instructions, 40 bytes at 0x...)
HEADER_RE = re.compile(r"^(?:main|function) <(?P<file>.+):(?P<start>\d+),(?P<end>\d+)>")

# The line after each header carries the counts:
#   0+ params, 7 slots, 0 upvalues, 6 locals, 2 constants, 5 functions
# Singular forms such as "1 local" and "1 slot" occur too, hence the optional "s".
COUNTS_RE = re.compile(
    r"^(?P<params>\d+)\+? params, "
    r"(?P<slots>\d+) slots?, "
    r"(?P<upvalues>\d+) upvalues?, "
    r"(?P<locals>\d+) locals?, "
)

# The compiler's own message when a limit is actually breached.
LIMIT_ERROR_RE = re.compile(r"has more than \d+ (?:local variables|upvalues)")


@dataclass
class FunctionInfo:
    """One Lua function (or file chunk) and its compiler-reported counts."""

    path: str
    line_start: int
    line_end: int
    params: int
    slots: int
    upvalues: int
    declared_locals: int

    @property
    def is_over_limit(self) -> bool:
        """Upvalues are exact, so 60 means there is no headroom left.

        Slots deliberately do not count here: the register high-water mark
        includes temporaries, so a healthy function can report slightly over
        200 slots while its active locals stay within the limit. A genuine
        local-variable breach shows up as a compile error instead.
        """
        return self.upvalues >= UPVALUE_LIMIT

    def is_near_limit(self, ratio: float) -> bool:
        return self.slots >= LOCAL_LIMIT * ratio or self.upvalues >= UPVALUE_LIMIT * ratio

    def pressure(self) -> float:
        """How close this function is to whichever limit it is nearest."""
        return max(self.slots / LOCAL_LIMIT, self.upvalues / UPVALUE_LIMIT)

    def describe(self) -> str:
        location = f"{self.path}:{self.line_start}"
        if self.line_end and self.line_end != self.line_start:
            location += f"-{self.line_end}"
        return (
            f"{location}: {self.slots}/{LOCAL_LIMIT} slots, "
            f"{self.upvalues}/{UPVALUE_LIMIT} upvalues "
            f"({self.declared_locals} locals declared)"
        )


def find_luac() -> str:
    """Return a Lua 5.1 compiler, preferring an explicitly versioned binary."""
    for candidate in ("luac5.1", "luac-5.1", "luac"):
        path = shutil.which(candidate)
        if not path:
            continue
        try:
            probe = subprocess.run([path, "-v"], capture_output=True, text=True, timeout=10)
        except (OSError, subprocess.SubprocessError):
            continue
        # luac prints its banner to stdout on some builds and stderr on others.
        if "Lua 5.1" in (probe.stdout + probe.stderr):
            return path

    sys.exit(
        "error: no Lua 5.1 compiler found. Install luac5.1 (Debian/Ubuntu: "
        "'lua5.1', Fedora: 'compat-lua-devel') and re-run."
    )


def make_exclusion_test(excludes: tuple[str, ...]):
    """Build a predicate matching paths inside any excluded directory."""
    normalised = tuple(exclude.replace("\\", "/").strip("/") for exclude in excludes if exclude)

    def is_excluded(path: Path) -> bool:
        posix = path.as_posix()
        if posix.startswith("./"):
            posix = posix[2:]
        return any(
            posix == exclude or posix.startswith(f"{exclude}/") or f"/{exclude}/" in posix
            for exclude in normalised
        )

    return is_excluded


def walk_directory(root: Path, is_excluded) -> list[Path]:
    """Yield every non-excluded .lua file below a directory."""
    found: list[Path] = []
    for dirpath, dirnames, filenames in os.walk(root):
        # Prune excluded directories so large trees are never walked.
        dirnames[:] = [name for name in dirnames if not is_excluded(Path(dirpath) / name)]
        for filename in filenames:
            if not filename.endswith(".lua"):
                continue
            candidate = Path(dirpath) / filename
            if not is_excluded(candidate):
                found.append(candidate)
    return found


def iter_lua_files(targets: list[str], excludes: tuple[str, ...]) -> list[Path]:
    """Collect .lua files under the given files/directories, skipping excludes."""
    is_excluded = make_exclusion_test(excludes)

    found: list[Path] = []
    for target in targets:
        root = Path(target)
        if root.is_file():
            found.append(root)
        elif root.exists():
            found.extend(walk_directory(root, is_excluded))
        else:
            sys.exit(f"error: no such file or directory: {target}")

    return sorted(set(found))


def parse_listing(listing: str, path: Path) -> list[FunctionInfo]:
    """Turn ``luac -l -l`` output into FunctionInfo records."""
    functions: list[FunctionInfo] = []
    pending: tuple[int, int] | None = None

    for line in listing.splitlines():
        header = HEADER_RE.match(line)
        if header:
            pending = (int(header.group("start")), int(header.group("end")))
            continue

        if pending is None:
            continue

        counts = COUNTS_RE.match(line)
        if counts:
            functions.append(
                FunctionInfo(
                    path=path.as_posix(),
                    line_start=pending[0],
                    line_end=pending[1],
                    params=int(counts.group("params")),
                    slots=int(counts.group("slots")),
                    upvalues=int(counts.group("upvalues")),
                    declared_locals=int(counts.group("locals")),
                )
            )
            pending = None

    return functions


def analyse(luac: str, path: Path) -> tuple[list[FunctionInfo], str | None, bool]:
    """Compile one file.

    Returns its functions, an error message, and whether that error was a
    breached Lua limit rather than an unrelated syntax error.
    """
    try:
        result = subprocess.run(
            [luac, "-p", "-l", "-l", str(path)],
            capture_output=True,
            text=True,
            timeout=60,
        )
    except subprocess.TimeoutExpired:
        return [], "timed out while compiling", False
    except OSError as error:
        return [], str(error), False

    if result.returncode != 0:
        output = (result.stderr or result.stdout).strip().splitlines()
        message = output[-1] if output else "failed to compile"
        # luac prefixes its own program name; the source location is the useful
        # part. Split rather than regex-match, to avoid pathological backtracking.
        prefix, separator, remainder = message.partition(": ")
        if separator and "luac" in prefix:
            message = remainder.strip()
        return [], message, bool(LIMIT_ERROR_RE.search(message))

    return parse_listing(result.stdout, path), None, False


@dataclass
class Report:
    """Everything one audit run found."""

    files_scanned: int
    functions: list[FunctionInfo]
    limit_errors: list[tuple[str, str]]
    failures: list[tuple[str, str]]

    @property
    def has_problems(self) -> bool:
        return bool(self.over or self.limit_errors or self.failures)

    @property
    def over(self) -> list[FunctionInfo]:
        return [function for function in self.functions if function.is_over_limit]

    def near(self, ratio: float) -> list[FunctionInfo]:
        return [
            function
            for function in self.functions
            if function.is_near_limit(ratio) and not function.is_over_limit
        ]

    def tightest(self) -> list[FunctionInfo]:
        return sorted(self.functions, key=FunctionInfo.pressure, reverse=True)


def collect(luac: str, files: list[Path]) -> Report:
    """Compile every file and gather its per-function counts."""
    functions: list[FunctionInfo] = []
    limit_errors: list[tuple[str, str]] = []
    failures: list[tuple[str, str]] = []

    for path in files:
        parsed, error, is_limit_error = analyse(luac, path)
        if error:
            (limit_errors if is_limit_error else failures).append((path.as_posix(), error))
        functions.extend(parsed)

    return Report(len(files), functions, limit_errors, failures)


def print_text_report(report: Report, warn_ratio: float, top: int, quiet: bool) -> None:
    """Render the human-readable report."""
    for path, error in report.limit_errors:
        print(f"LIMIT   {path}: {error}")

    for path, error in report.failures:
        print(f"FAILED  {path}: {error}")

    for function in sorted(report.over, key=FunctionInfo.pressure, reverse=True):
        print(f"AT LIMIT {function.describe()}")

    for function in sorted(report.near(warn_ratio), key=FunctionInfo.pressure, reverse=True):
        print(f"NEAR    {function.describe()}")

    if top:
        print(f"\nLeast headroom ({top} functions):")
        for function in report.tightest()[:top]:
            print(f"        {function.describe()}")

    if not quiet:
        print(
            f"\nScanned {len(report.functions)} functions in {report.files_scanned} files "
            f"(limits: {LOCAL_LIMIT} locals, {UPVALUE_LIMIT} upvalues)."
        )
        if not report.has_problems:
            print("No function is at or over a hard limit.")


def build_json_payload(report: Report, warn_ratio: float, top: int) -> dict:
    """Render the machine-readable report."""
    return {
        "limits": {"locals": LOCAL_LIMIT, "upvalues": UPVALUE_LIMIT},
        "filesScanned": report.files_scanned,
        "functionsScanned": len(report.functions),
        "limitErrors": [{"path": path, "error": error} for path, error in report.limit_errors],
        "overLimit": [asdict(function) for function in report.over],
        "nearLimit": [asdict(function) for function in report.near(warn_ratio)],
        "top": [asdict(function) for function in report.tightest()[:top]],
        "failures": [{"path": path, "error": error} for path, error in report.failures],
    }


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Audit Lua 5.1 per-function local and upvalue headroom.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "paths",
        nargs="*",
        default=["."],
        help="files or directories to audit (default: the whole repository)",
    )
    parser.add_argument(
        "--warn-ratio",
        type=float,
        default=0.8,
        metavar="R",
        help="report functions at or above this fraction of a limit (default: 0.8)",
    )
    parser.add_argument(
        "--top",
        type=int,
        default=0,
        metavar="N",
        help="also list the N functions with the least headroom",
    )
    parser.add_argument(
        "--exclude",
        action="append",
        default=[],
        metavar="PATH",
        help="additional path fragment to skip (repeatable)",
    )
    parser.add_argument("--json", action="store_true", help="emit JSON instead of text")
    parser.add_argument(
        "--quiet", action="store_true", help="only report problems, not the summary"
    )
    return parser.parse_args()


def main() -> int:
    args = parse_arguments()

    luac = find_luac()
    files = iter_lua_files(args.paths, DEFAULT_EXCLUDES + tuple(args.exclude))
    if not files:
        print("no .lua files found", file=sys.stderr)
        return 0

    report = collect(luac, files)

    if args.json:
        print(json.dumps(build_json_payload(report, args.warn_ratio, args.top), indent=2))
    else:
        print_text_report(report, args.warn_ratio, args.top, args.quiet)

    return 1 if report.has_problems else 0


if __name__ == "__main__":
    sys.exit(main())
