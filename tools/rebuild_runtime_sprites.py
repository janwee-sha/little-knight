#!/usr/bin/env python3
"""Rebuild all shipped sprite frames from the deterministic runtime manifest."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from embed_sprite_frames import embed_frames


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = REPOSITORY_ROOT / "assets/sprites/runtime_manifest.json"
DEFAULT_SOURCE_ROOT = REPOSITORY_ROOT / "assets/sprites/frames"
DEFAULT_OUTPUT_ROOT = REPOSITORY_ROOT / "assets/sprites/runtime"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--source-root", type=Path, default=DEFAULT_SOURCE_ROOT)
    parser.add_argument("--output-root", type=Path, default=DEFAULT_OUTPUT_ROOT)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    characters = manifest.get("characters")
    if not isinstance(characters, dict) or not characters:
        raise SystemExit("Manifest must contain a non-empty 'characters' object")

    rebuilt = 0
    for character, definition in characters.items():
        canvas_size = int(definition["canvas_size"])
        animations = definition.get("animations")
        if not isinstance(animations, dict) or not animations:
            raise SystemExit(f"{character} must define at least one animation")
        for animation, scale_value in animations.items():
            source_dir = args.source_root / character / animation
            output_dir = args.output_root / character / animation
            try:
                embed_frames(
                    source_dir,
                    output_dir,
                    canvas_size=canvas_size,
                    scale=float(scale_value),
                )
            except ValueError as error:
                raise SystemExit(f"{character}/{animation}: {error}") from error
            rebuilt += 1

    print(f"Rebuilt {rebuilt} animation directories from {args.manifest}")


if __name__ == "__main__":
    main()
