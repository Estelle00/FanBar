#!/usr/bin/env python3
"""Summarize `swift test --enable-code-coverage` results and gate on them.

Reports line coverage for Sources/ and, when a base ref is given, coverage of
only the executable lines added since that ref ("diff coverage"). The gate is
deliberately about new code: legacy files are not forced up to a target.

Usage:
  swift test --enable-code-coverage
  python3 scripts/coverage-report.py [--base origin/main] [--min-diff 60] [--min-diff-lines 5] [--min-total 0]

Writes .build/coverage.lcov (for Codecov or other tools) as a side effect.
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE_PREFIX = "Sources/"
# The C SMC bridge talks to real hardware and is not reachable from unit tests.
IGNORED_PREFIXES = ("Sources/AppleSMC/",)


def run(*args: str) -> str:
    return subprocess.run(args, cwd=ROOT, check=True, capture_output=True, text=True).stdout


def find_test_binaries(codecov_json: Path) -> list[Path]:
    build_dir = codecov_json.parent.parent
    # The native build system emits one <Package>PackageTests.xctest; swift-build
    # (the default from Swift 6.3) emits one bundle per test target.
    bundles = sorted(build_dir.glob("*.xctest"))
    if not bundles:
        sys.exit(f"No .xctest bundle in {build_dir}; run swift test first.")
    binaries = []
    for bundle in bundles:
        binary = bundle / "Contents" / "MacOS" / bundle.stem
        binaries.append(binary if binary.exists() else bundle)
    return binaries


def export_lcov() -> dict[str, dict[int, int]]:
    codecov_json = Path(run("swift", "test", "--show-codecov-path").strip())
    profdata = codecov_json.parent / "default.profdata"
    if not profdata.exists():
        sys.exit(f"Missing {profdata}; run `swift test --enable-code-coverage` first.")
    first, *others = find_test_binaries(codecov_json)
    objects = [arg for binary in others for arg in ("-object", str(binary))]
    lcov = run("xcrun", "llvm-cov", "export", "-format=lcov", f"-instr-profile={profdata}", str(first), *objects)
    (ROOT / ".build").mkdir(exist_ok=True)
    (ROOT / ".build" / "coverage.lcov").write_text(lcov)

    files: dict[str, dict[int, int]] = {}
    current: dict[int, int] | None = None
    for line in lcov.splitlines():
        if line.startswith("SF:"):
            path = os.path.relpath(line[3:], ROOT)
            keep = path.startswith(SOURCE_PREFIX) and not path.startswith(IGNORED_PREFIXES)
            current = files.setdefault(path, {}) if keep else None
        elif line.startswith("DA:") and current is not None:
            number, count = line[3:].split(",")[:2]
            # A file linked into several test bundles appears once per bundle.
            current[int(number)] = max(current.get(int(number), 0), int(count))
    return files


def added_lines(base: str) -> dict[str, set[int]]:
    merge_base = run("git", "merge-base", base, "HEAD").strip()
    diff = run("git", "diff", "--unified=0", "--no-color", merge_base, "--", SOURCE_PREFIX)
    result: dict[str, set[int]] = defaultdict(set)
    path = None
    for line in diff.splitlines():
        if line.startswith("+++ "):
            path = None if line.endswith("/dev/null") else line[6:]
        elif line.startswith("@@") and path:
            match = re.search(r"\+(\d+)(?:,(\d+))?", line)
            start, length = int(match.group(1)), int(match.group(2) or 1)
            result[path].update(range(start, start + length))
    return result


def percent(covered: int, total: int) -> float:
    return 100.0 * covered / total if total else 100.0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", help="git ref to compute diff coverage against, e.g. origin/main")
    parser.add_argument("--min-diff", type=float, default=0.0, help="minimum diff coverage percent")
    parser.add_argument(
        "--min-diff-lines",
        type=int,
        default=5,
        help="only enforce --min-diff when the diff adds at least this many executable lines",
    )
    parser.add_argument("--min-total", type=float, default=0.0, help="minimum total coverage percent")
    args = parser.parse_args()

    files = export_lcov()
    total_lines = sum(len(lines) for lines in files.values())
    total_hit = sum(1 for lines in files.values() for count in lines.values() if count > 0)
    total_pct = percent(total_hit, total_lines)

    print(f"{'File':<60} {'Lines':>7} {'Cover':>7}")
    for path in sorted(files):
        lines = files[path]
        hit = sum(1 for count in lines.values() if count > 0)
        print(f"{path:<60} {len(lines):>7} {percent(hit, len(lines)):>6.1f}%")
    print(f"{'TOTAL':<60} {total_lines:>7} {total_pct:>6.1f}%")

    failed = False
    if total_pct < args.min_total:
        print(f"\n✗ Total coverage {total_pct:.1f}% is below {args.min_total:.1f}%")
        failed = True

    if args.base:
        diff_total = diff_hit = 0
        uncovered: list[str] = []
        for path, numbers in sorted(added_lines(args.base).items()):
            executable = files.get(path, {})
            for number in sorted(numbers & executable.keys()):
                diff_total += 1
                if executable[number] > 0:
                    diff_hit += 1
                else:
                    uncovered.append(f"{path}:{number}")
        diff_pct = percent(diff_hit, diff_total)
        print(f"\nDiff coverage vs {args.base}: {diff_hit}/{diff_total} lines ({diff_pct:.1f}%)")
        if uncovered:
            print("Uncovered new lines:")
            for location in uncovered[:50]:
                print(f"  {location}")
            if len(uncovered) > 50:
                print(f"  … {len(uncovered) - 50} more")
        if diff_total >= args.min_diff_lines and diff_pct < args.min_diff:
            print(f"✗ Diff coverage {diff_pct:.1f}% is below {args.min_diff:.1f}%")
            failed = True

    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a") as handle:
            handle.write(f"### Coverage\n\nTotal line coverage (Sources/): **{total_pct:.1f}%**\n")
            if args.base:
                handle.write(f"\nDiff coverage vs `{args.base}`: **{diff_pct:.1f}%** ({diff_hit}/{diff_total})\n")

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
