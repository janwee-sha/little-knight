#!/usr/bin/env python3
"""Repack separated sprites into equal horizontal slots before normalization.

Image generators commonly leave uneven outer margins even when a fixed slot count
is requested.  The runtime normalization tool intentionally assumes equal slots,
so this small preprocessing step finds the occupied column runs and packs them
into a deterministic strip without rescaling individual frames.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--frames", type=int, required=True)
    parser.add_argument("--alpha-threshold", type=int, default=8)
    parser.add_argument("--min-run-width", type=int, default=8)
    parser.add_argument("--padding", type=int, default=8)
    return parser.parse_args()


def occupied_runs(image: Image.Image, threshold: int) -> list[tuple[int, int]]:
    alpha = image.getchannel("A")
    occupied = [
        alpha.crop((x, 0, x + 1, image.height)).getextrema()[1] > threshold
        for x in range(image.width)
    ]
    runs: list[tuple[int, int]] = []
    start: int | None = None
    for x, is_occupied in enumerate([*occupied, False]):
        if is_occupied and start is None:
            start = x
        elif not is_occupied and start is not None:
            runs.append((start, x))
            start = None
    return runs


def alpha_bbox(image: Image.Image, threshold: int) -> tuple[int, int, int, int] | None:
    mask = image.getchannel("A").point(lambda value: 255 if value > threshold else 0)
    return mask.getbbox()


def main() -> None:
    args = parse_args()
    if args.frames < 1:
        raise SystemExit("--frames must be at least 1")

    source = Image.open(args.input).convert("RGBA")
    runs = [
        run
        for run in occupied_runs(source, args.alpha_threshold)
        if run[1] - run[0] >= args.min_run_width
    ]
    if len(runs) != args.frames:
        raise SystemExit(
            f"Expected {args.frames} separated sprites, found {len(runs)} runs: {runs}"
        )

    frames: list[Image.Image] = []
    for left, right in runs:
        rough = source.crop((left, 0, right, source.height))
        bbox = alpha_bbox(rough, args.alpha_threshold)
        if bbox is None:
            raise SystemExit("Detected an empty sprite run")
        frames.append(rough.crop(bbox))

    slot_width = max(frame.width for frame in frames) + args.padding * 2
    strip_height = max(frame.height for frame in frames) + args.padding * 2
    strip = Image.new("RGBA", (slot_width * args.frames, strip_height), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        x = index * slot_width + (slot_width - frame.width) // 2
        y = strip_height - args.padding - frame.height
        strip.alpha_composite(frame, (x, y))

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    strip.save(output)


if __name__ == "__main__":
    main()
