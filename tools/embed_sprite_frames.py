#!/usr/bin/env python3
"""Place normalized frames on one shared bottom-centered runtime canvas.

One scale is applied to every frame passed to this command.  Scaling the entire
source canvas around its bottom-center keeps the authored foot anchor stable and
avoids per-frame alpha bounds (including attack effects) changing character size.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


def embed_frames(
    input_dir: Path,
    output_dir: Path,
    canvas_size: int = 128,
    scale: float = 1.0,
) -> None:
    if canvas_size < 1:
        raise ValueError("canvas_size must be at least 1")
    if scale <= 0.0:
        raise ValueError("scale must be greater than 0")

    output_dir.mkdir(parents=True, exist_ok=True)
    frame_paths = sorted(input_dir.glob("*.png"))
    if not frame_paths:
        raise ValueError(f"No PNG frames found in {input_dir}")

    for frame_path in frame_paths:
        frame = Image.open(frame_path).convert("RGBA")
        if scale != 1.0:
            scaled_size = (
                max(1, round(frame.width * scale)),
                max(1, round(frame.height * scale)),
            )
            frame = frame.resize(scaled_size, Image.Resampling.NEAREST)
        if frame.width > canvas_size or frame.height > canvas_size:
            raise ValueError(
                f"{frame_path} becomes {frame.width}x{frame.height}, larger than "
                f"{canvas_size}x{canvas_size}"
            )
        canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
        x = (canvas_size - frame.width) // 2
        y = canvas_size - frame.height
        canvas.alpha_composite(frame, (x, y))
        canvas.save(output_dir / frame_path.name)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-dir", required=True)
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--canvas-size", type=int, default=128)
    parser.add_argument(
        "--scale",
        type=float,
        default=1.0,
        help="Shared scale for the entire animation strip (default: 1.0)",
    )
    args = parser.parse_args()

    try:
        embed_frames(
            Path(args.input_dir),
            Path(args.output_dir),
            args.canvas_size,
            args.scale,
        )
    except ValueError as error:
        raise SystemExit(str(error)) from error


if __name__ == "__main__":
    main()
