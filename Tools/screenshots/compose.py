#!/usr/bin/env python3
"""Turn framed device mockups into upload-ready App Store screenshots.

frame.py leaves the device on transparency at 1530x3036 — larger than any
App Store slot, so it cannot be uploaded as-is. This composes each one onto a
canvas of exactly the required size (6.9" iPhone = 1320x2868) with a caption,
and writes straight into fastlane/screenshots/<App Store locale>/ where
`deliver` expects it.

Usage: compose.py [--framed-dir DIR] [--out-dir DIR] [--captions FILE]
"""

import argparse
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent.parent

# 6.9" iPhone display slot, which is what the iPhone 17 Pro Max simulator
# captures natively. 1290x2796 is also accepted.
CANVAS = (1320, 2868)

# Capture locale -> App Store Connect locale directory name.
LOCALE_DIRS = {
    "en": "en-US",
    "es": "es-ES",
    "ca": "ca",
    "fr": "fr-FR",
    "it": "it",
    "ja": "ja",
    "pt-PT": "pt-PT",
}

# Straight from ReverseSinging/Design/Colors.swift. The app is dark-only — it
# forces .dark in ContentView — so the marketing canvas is too. A cream canvas
# would put a bright halo around a near-black phone.
PALETTE = {
    "canvas": "#0E0F11",   # rsSurface0
    "ink": "#E8EAEC",      # rsTextPrimary
    "accent": "#E5484D",   # rsRecord
}

# Eugello is the app's own display face, already in the repo. It has no CJK
# coverage, so Japanese falls back to Hiragino rather than rendering tofu.
DISPLAY_FONT = REPO_ROOT / "ReverseSinging" / "Eugello.ttf"
LATIN_FALLBACKS = [
    "/System/Library/Fonts/Supplemental/Futura.ttc",
    "/System/Library/Fonts/HelveticaNeue.ttc",
]
CJK_FONTS = [
    "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc",
    "/System/Library/Fonts/ヒラギノ角ゴ ProN W6.otf",
    "/System/Library/Fonts/Hiragino Sans GB.ttc",
]
CJK_LOCALES = {"ja"}

TITLE_SIZE = 88
CJK_TITLE_SIZE = 74      # CJK glyphs are square and read larger at the same point size
MIN_TITLE_SIZE = 58      # below this a caption stops reading as a headline
CAPTION_MAX_WIDTH = 1140 # keeps the longest line clear of both canvas edges
LINE_SPACING = 26
TOP_MARGIN = 200
RULE_GAP = 44            # between the caption block and the accent rule
RULE_WIDTH = 96
RULE_HEIGHT = 5
DEVICE_WIDTH_RATIO = 0.88
DEVICE_BLEED = 90        # how far the device runs past the bottom edge


def font_path(locale: str) -> tuple[list[str], int]:
    if locale in CJK_LOCALES:
        return CJK_FONTS, CJK_TITLE_SIZE
    return [str(DISPLAY_FONT)] + LATIN_FALLBACKS, TITLE_SIZE


def load_font(locale: str, size: int | None = None) -> ImageFont.FreeTypeFont:
    candidates, default_size = font_path(locale)
    size = default_size if size is None else size

    for path in candidates:
        if not Path(path).exists():
            continue
        try:
            font = ImageFont.truetype(path, size)
        except OSError:
            continue
        # Some system faces are variable fonts. Without pinning a named instance
        # Pillow renders from an unset default and mangles glyphs.
        try:
            font.set_variation_by_name("Regular")
        except (OSError, AttributeError):
            pass
        return font

    print(f"!!  no font found for locale {locale}, falling back to the default",
          file=sys.stderr)
    return ImageFont.load_default()


def fit_font(locale: str, lines: list[str], measure: ImageDraw.ImageDraw):
    """Shrinks the headline until its widest line clears the canvas edges.

    French and Portuguese captions run a third longer than the English they were
    written against; without this they set past the frame and get silently cropped
    by the App Store's own thumbnailing.
    """
    _, size = font_path(locale)
    while size > MIN_TITLE_SIZE:
        font = load_font(locale, size)
        widest = max((measure.textbbox((0, 0), line, font=font)[2] for line in lines),
                     default=0)
        if widest <= CAPTION_MAX_WIDTH:
            return font
        size -= 2
    return load_font(locale, MIN_TITLE_SIZE)


def compose(framed_path: Path, out_path: Path, caption: str, locale: str):
    canvas = Image.new("RGBA", CANVAS, PALETTE["canvas"])
    draw = ImageDraw.Draw(canvas)

    # --- Caption ---
    lines = caption.split("\n")
    font = fit_font(locale, lines, draw)
    y = TOP_MARGIN
    for line in lines:
        bbox = draw.textbbox((0, 0), line, font=font)
        w = bbox[2] - bbox[0]
        draw.text(((CANVAS[0] - w) / 2 - bbox[0], y), line, font=font, fill=PALETTE["ink"])
        y += (bbox[3] - bbox[1]) + LINE_SPACING

    # A short red rule under the caption: the one saturated colour in the app is
    # the record state, and this is the only place the marketing frame borrows it.
    rule_y = y - LINE_SPACING + RULE_GAP
    draw.rectangle(
        [(CANVAS[0] - RULE_WIDTH) // 2, rule_y,
         (CANVAS[0] + RULE_WIDTH) // 2, rule_y + RULE_HEIGHT],
        fill=PALETTE["accent"],
    )

    # --- Device ---
    device = Image.open(framed_path).convert("RGBA")
    target_w = int(CANVAS[0] * DEVICE_WIDTH_RATIO)
    target_h = int(device.height * (target_w / device.width))
    device = device.resize((target_w, target_h), Image.LANCZOS)

    x = (CANVAS[0] - target_w) // 2
    # Anchored to the bottom and allowed to run past it — the phone bleeds off
    # the edge, which reads as a product shot rather than a floating rectangle.
    y_device = CANVAS[1] - target_h + DEVICE_BLEED
    canvas.alpha_composite(device, (x, y_device))

    out_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(out_path, "PNG")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--framed-dir", type=Path, default=SCRIPT_DIR / "output" / "framed")
    parser.add_argument("--out-dir", type=Path, default=REPO_ROOT / "fastlane" / "screenshots")
    parser.add_argument("--captions", type=Path, default=SCRIPT_DIR / "captions.json")
    args = parser.parse_args()

    if not args.framed_dir.is_dir():
        sys.exit(f"error: framed dir not found: {args.framed_dir}")

    captions = json.loads(args.captions.read_text(encoding="utf-8"))

    shots = sorted(args.framed_dir.glob("*/*.png"))
    if not shots:
        sys.exit(f"error: no framed PNGs under {args.framed_dir}")

    missing = []
    count = 0
    for shot in shots:
        locale = shot.parent.name
        stem = shot.stem                      # e.g. "00_dubRecord"
        screen = stem.split("_", 1)[1] if "_" in stem else stem

        caption = captions.get(screen, {}).get(locale)
        if caption is None:
            missing.append(f"{locale}/{screen}")
            caption = ""

        out_dir = args.out_dir / LOCALE_DIRS.get(locale, locale)
        compose(shot, out_dir / f"{stem}.png", caption, locale)
        count += 1

    print(f"==> {count} App Store screenshots ({CANVAS[0]}x{CANVAS[1]}) in {args.out_dir}")
    if missing:
        # Loud, because a silently blank caption looks like a design choice.
        print(f"!!  no caption for: {', '.join(missing)}", file=sys.stderr)


if __name__ == "__main__":
    main()
