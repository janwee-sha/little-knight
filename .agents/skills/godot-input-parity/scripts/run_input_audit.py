#!/usr/bin/env python3
"""Run the live Godot InputMap auditor and reject false-positive exits."""

from __future__ import annotations

import argparse
import os
import platform
import re
import shlex
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Optional


SUCCESS_MARKER = "Godot input parity audit: PASS"
FATAL_PATTERNS = (
    re.compile(r"^ERROR:", re.MULTILINE),
    re.compile(r"SCRIPT ERROR", re.IGNORECASE),
    re.compile(r"Parse Error", re.IGNORECASE),
    re.compile(r"Invalid access", re.IGNORECASE),
    re.compile(r"handle_crash", re.IGNORECASE),
    re.compile(r"Segmentation fault", re.IGNORECASE),
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", type=Path, default=Path.cwd())
    parser.add_argument("--contract", type=Path, required=True)
    parser.add_argument("--godot", help="Godot executable; otherwise auto-discover")
    parser.add_argument("--timeout", type=float, default=60.0)
    return parser.parse_args()


def discover_godot(explicit: Optional[str]) -> str:
    candidates = [
        explicit,
        os.environ.get("GODOT_BIN"),
        shutil.which("godot4"),
        shutil.which("godot"),
    ]
    if platform.system() == "Darwin":
        candidates.append("/Applications/Godot.app/Contents/MacOS/Godot")
    for candidate in candidates:
        if not candidate:
            continue
        resolved = shutil.which(candidate) or candidate
        if Path(resolved).is_file():
            return str(Path(resolved).resolve())
    raise RuntimeError("Godot executable not found; pass --godot or set GODOT_BIN")


def main() -> int:
    args = parse_args()
    project = args.project.resolve()
    contract = args.contract.resolve()
    auditor = Path(__file__).with_name("audit_input_map.gd").resolve()
    if not (project / "project.godot").is_file():
        print(f"Not a Godot project: {project}", file=sys.stderr)
        return 2
    if not contract.is_file():
        print(f"Input contract not found: {contract}", file=sys.stderr)
        return 2
    try:
        godot = discover_godot(args.godot)
    except RuntimeError as error:
        print(error, file=sys.stderr)
        return 2

    command = [
        godot,
        "--headless",
        "--path",
        str(project),
        "-s",
        str(auditor),
        "--",
        "--contract",
        str(contract),
    ]
    print(f"[input-audit] {shlex.join(command)}", flush=True)
    try:
        result = subprocess.run(
            command,
            cwd=project,
            capture_output=True,
            text=True,
            timeout=args.timeout,
            check=False,
        )
    except subprocess.TimeoutExpired as error:
        output = (error.stdout or "") + (error.stderr or "")
        if output:
            print(output, end="" if output.endswith("\n") else "\n")
        print(f"[input-audit] FAIL: timed out after {args.timeout:g}s", file=sys.stderr)
        return 1

    output = result.stdout + result.stderr
    if output:
        print(output, end="" if output.endswith("\n") else "\n")
    failures: list[str] = []
    if result.returncode != 0:
        failures.append(f"exit status {result.returncode}")
    fatal_matches = [pattern.pattern for pattern in FATAL_PATTERNS if pattern.search(output)]
    if fatal_matches:
        failures.append("fatal Godot log marker(s): " + ", ".join(fatal_matches))
    if SUCCESS_MARKER not in output:
        failures.append(f"missing success marker {SUCCESS_MARKER!r}")
    if failures:
        print(f"[input-audit] FAIL: {'; '.join(failures)}", file=sys.stderr)
        return 1
    print("[input-audit] PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
