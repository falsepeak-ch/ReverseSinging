#!/usr/bin/env python3
"""Composite raw simulator screenshots into a mockuphone.com device frame.

Reads frames/device.json for the frame, mask, and screen coordinates,
then for every PNG under output/raw/<locale>/ produces a framed PNG at
output/framed/<locale>/ with the same name.

The output is the bare device on transparency — larger than any App Store
slot. compose.py turns these into upload-ready marketing screenshots.

Usage: frame.py [--scale 0.5] [--raw-dir DIR] [--out-dir DIR]
"""

import argparse
import json
import sys
from pathlib import Path

from PIL import Image

SCRIPT_DIR = Path(__file__).resolve().parent


def load_device(frames_dir: Path):
    device = json.loads((frames_dir / "device.json").read_text())
    frame = Image.open(frames_dir / device["frame_image"]).convert("RGBA")
    mask = Image.open(frames_dir / device["mask_image"]).convert("RGBA")
    coords = device["portrait_coords"]
    xs = [p[0] for p in coords]
    ys = [p[1] for p in coords]
    screen_box = (min(xs), min(ys), max(xs), max(ys))  # axis-aligned screen rect
    return device, frame, mask, screen_box


def frame_screenshot(shot_path: Path, out_path: Path, frame, mask, screen_box, scale):
    shot = Image.open(shot_path).convert("RGBA")
    x0, y0, x1, y1 = screen_box
    w, h = x1 - x0, y1 - y0

    shot = shot.resize((w, h), Image.LANCZOS)

    canvas = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    canvas.paste(shot, (x0, y0))

    # The mask's alpha channel defines the visible screen area
    # (rounded corners / Dynamic Island cutout).
    canvas.putalpha(
        Image.composite(
            canvas.getchannel("A"),
            Image.new("L", frame.size, 0),
            mask.getchannel("A"),
        )
    )

    result = Image.alpha_composite(canvas, frame)

    if scale != 1.0:
        result = result.resize(
            (int(result.width * scale), int(result.height * scale)), Image.LANCZOS
        )

    out_path.parent.mkdir(parents=True, exist_ok=True)
    result.save(out_path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scale", type=float, default=1.0)
    parser.add_argument("--raw-dir", type=Path, default=SCRIPT_DIR / "output" / "raw")
    parser.add_argument("--out-dir", type=Path, default=SCRIPT_DIR / "output" / "framed")
    parser.add_argument("--frames-dir", type=Path, default=SCRIPT_DIR / "frames")
    args = parser.parse_args()

    if not args.raw_dir.is_dir():
        sys.exit(f"error: raw screenshot dir not found: {args.raw_dir}")

    device, frame, mask, screen_box = load_device(args.frames_dir)
    print(f"==> Framing with {device['name']} ({device['color']}), screen rect {screen_box}")

    shots = sorted(args.raw_dir.glob("*/*.png"))
    if not shots:
        sys.exit(f"error: no PNGs found under {args.raw_dir}")

    for shot_path in shots:
        rel = shot_path.relative_to(args.raw_dir)
        out_path = args.out_dir / rel
        frame_screenshot(shot_path, out_path, frame, mask, screen_box, args.scale)
        print(f"    {rel}")

    print(f"==> {len(shots)} framed screenshots in {args.out_dir}")


if __name__ == "__main__":
    main()
