#!/usr/bin/env python3
"""Turn compiler errors from an xcodebuild log into GitHub Actions annotations.

GitHub shows at most 10 error annotations per step, so the workflow calls this script
several times with a different --offset. Annotations are visible on the run page and
through the API (check-run annotations), which is handy when the raw log is not reachable.

usage: annotate-errors.py LOGFILE [--offset N] [--limit N]
"""
import argparse
import os
import re
import sys

FILE_ERROR = re.compile(r"^(?P<path>/[^:\n]+?):(?P<line>\d+):(?P<col>\d+): error: (?P<msg>.+)$")
BARE_ERROR = re.compile(r"^(?:xcodebuild: )?error: (?P<msg>.+)$")


def escape(text: str) -> str:
    return text.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def collect(path: str, workspace: str):
    seen, found = set(), []
    with open(path, errors="replace") as handle:
        for raw in handle:
            line = raw.rstrip("\n")
            m = FILE_ERROR.match(line)
            if m:
                rel = os.path.relpath(m["path"], workspace) if m["path"].startswith(workspace) else m["path"]
                key = (rel, m["line"], m["msg"])
                if key not in seen:
                    seen.add(key)
                    found.append((rel, int(m["line"]), int(m["col"]), m["msg"]))
                continue
            b = BARE_ERROR.match(line)
            if b:
                key = (None, None, b["msg"])
                if key not in seen:
                    seen.add(key)
                    found.append((None, None, None, b["msg"]))
    return found


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("log")
    parser.add_argument("--offset", type=int, default=0)
    parser.add_argument("--limit", type=int, default=10)
    args = parser.parse_args()

    if not os.path.exists(args.log):
        return 0
    workspace = os.environ.get("GITHUB_WORKSPACE", os.getcwd()).rstrip("/") + "/"
    errors = collect(args.log, workspace)
    if args.offset == 0:
        print(f"Found {len(errors)} distinct compiler error(s)", file=sys.stderr)
    for rel, line, col, msg in errors[args.offset:args.offset + args.limit]:
        if rel:
            print(f"::error file={rel},line={line},col={col},title=Compile error::{escape(msg)}")
        else:
            print(f"::error title=Build error::{escape(msg)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
