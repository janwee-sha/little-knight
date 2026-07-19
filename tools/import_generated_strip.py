#!/usr/bin/env python3
"""Normalize an evenly spaced generated sprite strip into runtime-ready frames."""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

from PIL import Image


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--frames", type=int, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--packed-output", type=Path, required=True)
    parser.add_argument("--preview-output", type=Path, required=True)
    parser.add_argument("--canvas-size", type=int, default=128)
    parser.add_argument("--max-height", type=int, required=True)
    parser.add_argument("--alpha-threshold", type=int, default=32)
    parser.add_argument(
        "--component-ratio",
        type=float,
        default=0.0,
        help="Remove disconnected alpha components smaller than this fraction of the largest.",
    )
    return parser.parse_args()


def remove_small_components(image: Image.Image, threshold: int, ratio: float) -> Image.Image:
    if ratio <= 0.0:
        return image
    alpha = image.getchannel("A")
    width, height = image.size
    pixels = alpha.load()
    visited = bytearray(width * height)
    components: list[list[tuple[int, int]]] = []
    for y in range(height):
        for x in range(width):
            offset = y * width + x
            if visited[offset] or pixels[x, y] < threshold:
                continue
            visited[offset] = 1
            queue = deque([(x, y)])
            component: list[tuple[int, int]] = []
            while queue:
                current_x, current_y = queue.popleft()
                component.append((current_x, current_y))
                for next_x, next_y in (
                    (current_x - 1, current_y), (current_x + 1, current_y),
                    (current_x, current_y - 1), (current_x, current_y + 1),
                ):
                    if next_x < 0 or next_y < 0 or next_x >= width or next_y >= height:
                        continue
                    next_offset = next_y * width + next_x
                    if visited[next_offset] or pixels[next_x, next_y] < threshold:
                        continue
                    visited[next_offset] = 1
                    queue.append((next_x, next_y))
            components.append(component)
    if not components:
        return image
    minimum_size = max(len(component) for component in components) * ratio
    keep = Image.new("L", image.size, 0)
    keep_pixels = keep.load()
    for component in components:
        if len(component) >= minimum_size:
            for x, y in component:
                keep_pixels[x, y] = pixels[x, y]
    filtered = image.copy()
    filtered.putalpha(keep)
    return filtered


def clean_crop(frame: Image.Image, threshold: int, component_ratio: float) -> Image.Image:
    rgba = frame.convert("RGBA")
    alpha = rgba.getchannel("A")
    alpha = alpha.point(lambda value: 0 if value < threshold else value)
    rgba.putalpha(alpha)
    rgba = remove_small_components(rgba, threshold, component_ratio)
    alpha = rgba.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError("generated strip contains an empty frame slot")
    return rgba.crop(bbox)


def checkerboard(width: int, height: int, cell: int = 8) -> Image.Image:
    image = Image.new("RGBA", (width, height), (228, 234, 240, 255))
    pixels = image.load()
    for y in range(height):
        for x in range(width):
            if (x // cell + y // cell) % 2:
                pixels[x, y] = (244, 247, 250, 255)
    return image


def main() -> None:
    args = parse_args()
    if args.frames < 1:
        raise SystemExit("--frames must be at least 1")
    source = Image.open(args.input).convert("RGBA")
    frames: list[Image.Image] = []
    for index in range(args.frames):
        left = round(index * source.width / args.frames)
        right = round((index + 1) * source.width / args.frames)
        try:
            frames.append(clean_crop(
                source.crop((left, 0, right, source.height)),
                args.alpha_threshold,
                args.component_ratio,
            ))
        except ValueError as error:
            raise SystemExit(f"frame {index + 1}: {error}") from error

    max_source_height = max(frame.height for frame in frames)
    max_source_width = max(frame.width for frame in frames)
    scale = min(
        args.max_height / max_source_height,
        (args.canvas_size - 4) / max_source_width,
    )
    if scale <= 0.0:
        raise SystemExit("computed scale must be positive")

    args.output_dir.mkdir(parents=True, exist_ok=True)
    rendered: list[Image.Image] = []
    for index, frame in enumerate(frames, start=1):
        size = (max(1, round(frame.width * scale)), max(1, round(frame.height * scale)))
        resized = frame.resize(size, Image.Resampling.NEAREST)
        canvas = Image.new("RGBA", (args.canvas_size, args.canvas_size), (0, 0, 0, 0))
        x = (args.canvas_size - resized.width) // 2
        y = args.canvas_size - resized.height
        canvas.alpha_composite(resized, (x, y))
        canvas.save(args.output_dir / f"{index:02d}.png")
        rendered.append(canvas)

    packed_slot_width = max_source_width + 16
    packed_height = max_source_height + 16
    packed = Image.new("RGBA", (packed_slot_width * args.frames, packed_height), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        x = index * packed_slot_width + (packed_slot_width - frame.width) // 2
        y = packed_height - 8 - frame.height
        packed.alpha_composite(frame, (x, y))
    args.packed_output.parent.mkdir(parents=True, exist_ok=True)
    packed.save(args.packed_output)

    preview = checkerboard(args.canvas_size * args.frames, args.canvas_size)
    for index, frame in enumerate(rendered):
        preview.alpha_composite(frame, (index * args.canvas_size, 0))
    args.preview_output.parent.mkdir(parents=True, exist_ok=True)
    preview.save(args.preview_output)
    print(
        f"Imported {args.frames} frames from {args.input} at scale {scale:.4f}; "
        f"max source bounds {max_source_width}x{max_source_height}"
    )


if __name__ == "__main__":
    main()
