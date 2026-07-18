#!/usr/bin/env python3
"""Run Godot smoke and optional visual checks with strict log validation."""

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
    parser.add_argument("--godot", help="Godot executable; otherwise auto-discover")
    parser.add_argument("--smoke-script", default="tests/smoke_test.gd")
    parser.add_argument("--success-marker", default="PASS")
    parser.add_argument("--visual", action="store_true")
    parser.add_argument("--visual-script", default="tests/visual_capture.gd")
    parser.add_argument("--capture-dir", type=Path)
    parser.add_argument("--visual-headless", action="store_true")
    parser.add_argument("--rendering-method", default="gl_compatibility")
    parser.add_argument("--timeout", type=float, default=120.0)
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


def resolve_script(project: Path, raw_path: str, label: str) -> str:
    script = Path(raw_path)
    if not script.is_absolute():
        script = project / script
    if not script.is_file():
        raise RuntimeError(f"{label} script not found: {script}")
    try:
        return str(script.resolve().relative_to(project.resolve()))
    except ValueError:
        return str(script.resolve())


def snapshot_pngs(directory: Optional[Path]) -> dict[Path, tuple[int, int]]:
    if directory is None or not directory.exists():
        return {}
    return {
        path.resolve(): (path.stat().st_mtime_ns, path.stat().st_size)
        for path in directory.rglob("*.png")
        if path.is_file()
    }


def run_command(
    command: list[str],
    project: Path,
    timeout: float,
    success_marker: Optional[str],
    label: str,
) -> bool:
    print(f"[{label}] {shlex.join(command)}", flush=True)
    try:
        result = subprocess.run(
            command,
            cwd=project,
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
    except subprocess.TimeoutExpired as error:
        output = (error.stdout or "") + (error.stderr or "")
        if output:
            print(output, end="" if output.endswith("\n") else "\n")
        print(f"[{label}] FAIL: timed out after {timeout:g}s", file=sys.stderr)
        return False

    output = result.stdout + result.stderr
    if output:
        print(output, end="" if output.endswith("\n") else "\n")
    fatal_matches = [pattern.pattern for pattern in FATAL_PATTERNS if pattern.search(output)]
    failures: list[str] = []
    if result.returncode != 0:
        failures.append(f"exit status {result.returncode}")
    if fatal_matches:
        failures.append("fatal Godot log marker(s): " + ", ".join(fatal_matches))
    if success_marker and success_marker not in output:
        failures.append(f"missing success marker {success_marker!r}")
    if failures:
        print(f"[{label}] FAIL: {'; '.join(failures)}", file=sys.stderr)
        return False
    print(f"[{label}] PASS")
    return True


def main() -> int:
    args = parse_args()
    project = args.project.resolve()
    if not (project / "project.godot").is_file():
        print(f"Not a Godot project: {project}", file=sys.stderr)
        return 2
    try:
        godot = discover_godot(args.godot)
        smoke_script = resolve_script(project, args.smoke_script, "Smoke")
    except RuntimeError as error:
        print(error, file=sys.stderr)
        return 2

    smoke_command = [godot, "--headless", "--path", str(project), "-s", smoke_script]
    if not run_command(
        smoke_command, project, args.timeout, args.success_marker, "smoke"
    ):
        return 1

    if not args.visual:
        return 0

    try:
        visual_script = resolve_script(project, args.visual_script, "Visual")
    except RuntimeError as error:
        print(error, file=sys.stderr)
        return 2
    before = snapshot_pngs(args.capture_dir)
    visual_command = [godot]
    if args.visual_headless:
        visual_command.append("--headless")
    visual_command.extend(
        [
            "--path",
            str(project),
            "--rendering-method",
            args.rendering_method,
            "-s",
            visual_script,
        ]
    )
    if not run_command(visual_command, project, args.timeout, None, "visual"):
        return 1
    if args.capture_dir is not None:
        after = snapshot_pngs(args.capture_dir)
        changed = [path for path, state in after.items() if before.get(path) != state]
        if not changed:
            print(
                f"[visual] FAIL: no PNG capture was created or updated in "
                f"{args.capture_dir}",
                file=sys.stderr,
            )
            return 1
        print("[visual] Updated captures:")
        for path in sorted(changed):
            print(f"  {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
