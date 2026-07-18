#!/usr/bin/env python3
"""Place normalized frames on one shared bottom-centered runtime canvas."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-dir", required=True)
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--canvas-size", type=int, default=128)
    args = parser.parse_args()

    source = Path(args.input_dir)
    output = Path(args.output_dir)
    output.mkdir(parents=True, exist_ok=True)
    frame_paths = sorted(source.glob("*.png"))
    if not frame_paths:
        raise SystemExit(f"No PNG frames found in {source}")

    for frame_path in frame_paths:
        frame = Image.open(frame_path).convert("RGBA")
        if frame.width > args.canvas_size or frame.height > args.canvas_size:
            raise SystemExit(
                f"{frame_path} is larger than {args.canvas_size}x{args.canvas_size}"
            )
        canvas = Image.new(
            "RGBA", (args.canvas_size, args.canvas_size), (0, 0, 0, 0)
        )
        x = (args.canvas_size - frame.width) // 2
        y = args.canvas_size - frame.height
        canvas.alpha_composite(frame, (x, y))
        canvas.save(output / frame_path.name)


if __name__ == "__main__":
    main()
