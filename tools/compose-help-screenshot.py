#!/usr/bin/env python3
"""Composite raw emulator captures into the help-doc iPhone frame.

The help images under docs/assets/ are framed mockups (bezel + Dynamic Island),
not raw device captures. This keeps that look: the status/navigation bars are
cropped from a raw capture, the result is scaled into the screen area of an
existing framed mockup, and the Dynamic Island is redrawn on top.

Geometry below was measured from docs/assets/archive-*.png (all four share the
same template); it is not guessed. Both the mockup background and the app
background are the same cream, so a couple of pixels of imprecision at the
edges is invisible.

Usage:
    python3 tools/compose-help-screenshot.py \\
        --frame docs/assets/archive-timeline-en.png \\
        --capture /tmp/shots/en-timeline.png \\
        --out docs/assets/archive-timeline-en.png
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw

# Screen area inside the bezel of the 1302x2664 template (x0, y0, x1, y1).
# The bezel highlight (232,232,231) is within tolerance of the app cream, so the
# right edge is taken from where the cream actually ends, not from colour scan.
SCREEN = (36, 70, 1226, 2593)
SCREEN_RADIUS = 120
# Dynamic Island (x0, y0, x1, y1) inside the same template.
ISLAND = (472, 100, 829, 212)
ISLAND_RADIUS = 56
# Fraction of the raw capture occupied by the status bar and gesture bar.
TOP_INSET_RATIO = 0.037
BOTTOM_INSET_RATIO = 0.020
# Cream strip left above the app header so the Dynamic Island does not sit on
# top of the screen title (the template mockups leave the same gap).
TOP_GAP = 100
CREAM = (244, 237, 226)


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255
    )
    return mask


def compose(
    frame_path: Path,
    capture_path: Path,
    out_path: Path,
    screen: tuple[int, int, int, int],
    screen_radius: int,
    island: tuple[int, int, int, int] | None,
) -> None:
    frame = Image.open(frame_path).convert("RGB")
    capture = Image.open(capture_path).convert("RGB")

    width, height = capture.size
    content = capture.crop(
        (
            0,
            round(height * TOP_INSET_RATIO),
            width,
            height - round(height * BOTTOM_INSET_RATIO),
        )
    )

    x0, y0, x1, y1 = screen
    screen_w, screen_h = x1 - x0 + 1, y1 - y0 + 1

    # Scale by height (minus the gap the island needs), then fit the width:
    # crop when wider, centre on cream when narrower. Pillow's crop pads with
    # black past the image bounds, so never crop beyond them.
    visible_h = screen_h - TOP_GAP
    scale = visible_h / content.height
    scaled_w = round(content.width * scale)
    content = content.resize((scaled_w, visible_h), Image.LANCZOS)

    layer = Image.new("RGB", (screen_w, screen_h), CREAM)
    if scaled_w > screen_w:
        left = (scaled_w - screen_w) // 2
        content = content.crop((left, 0, left + screen_w, visible_h))
        layer.paste(content, (0, TOP_GAP))
    else:
        layer.paste(content, ((screen_w - scaled_w) // 2, TOP_GAP))
    frame.paste(layer, (x0, y0), rounded_mask((screen_w, screen_h), screen_radius))

    if island:
        ImageDraw.Draw(frame).rounded_rectangle(island, radius=ISLAND_RADIUS, fill=(0, 0, 0))

    out_path.parent.mkdir(parents=True, exist_ok=True)
    frame.save(out_path, optimize=True)
    print(f"{out_path}: {frame.size[0]}x{frame.size[1]} (screen {screen_w}x{screen_h})")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--frame", required=True, type=Path, help="existing framed mockup")
    parser.add_argument("--capture", required=True, type=Path, help="raw emulator screenshot")
    parser.add_argument("--out", required=True, type=Path, help="output PNG")
    parser.add_argument("--no-island", action="store_true", help="do not redraw the Dynamic Island")
    args = parser.parse_args()
    compose(
        args.frame,
        args.capture,
        args.out,
        SCREEN,
        SCREEN_RADIUS,
        None if args.no_island else ISLAND,
    )


if __name__ == "__main__":
    main()
