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

# The store palette, sampled from the 1.2.0 screenshots already on the App Store.
#
# Deliberately not the app's own near-black. The listing has had a cream field and a
# dark slate-teal headline since the first release, and the product page is the one
# place where continuity with what shoppers have already seen is worth more than
# matching the interface behind it.
PALETTE = {
    "canvas": "#F8F4D3",   # the cream field
    "ink": "#2E4245",      # headline
    "accent": "#E5484D",   # rsRecord, the app's one saturated colour
    "hero_panel": "#253A3F",
    "hero_ink": "#EDE9C6",
}

# The opening slide: wordmark, promise, and the app held at an angle. It is the only
# slide that is not a straight product shot, and the only one on the dark panel.
HERO_NAME = "00_hero"
HERO_SOURCE = "dubRecord"          # which captured screen the tilted phone shows
LOGO = REPO_ROOT / "ReverseSinging" / "Assets.xcassets" / "assets" / \
    "icon-lettering.imageset" / "Group@3x.png"

HERO_LOGO_WIDTH_RATIO = 0.74
HERO_LOGO_TOP = 250
HERO_TAGLINE_GAP = 78
HERO_TAGLINE_SIZE = 66
HERO_CJK_TAGLINE_SIZE = 56
HERO_TAGLINE_SPACING = 22
HERO_DEVICE_GAP = 170              # between the tagline and the top of the phone
HERO_DEVICE_WIDTH_RATIO = 0.70     # big enough to read, small enough to sit clear of the edges
HERO_TILT = 4.5                    # degrees, anticlockwise — a held angle, not a jaunty one
HERO_PERSPECTIVE = 0.045           # bottom edge drawn in, so the phone leans away

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


def _perspective_coeffs(source, target):
    """Pillow's PERSPECTIVE transform wants the inverse map as eight coefficients.

    Solving the 8x8 system here rather than pulling in numpy: this is the only linear
    algebra in the pipeline, and the venv is otherwise just Pillow.
    """
    matrix = []
    for (sx, sy), (tx, ty) in zip(source, target):
        matrix.append([tx, ty, 1, 0, 0, 0, -sx * tx, -sx * ty])
        matrix.append([0, 0, 0, tx, ty, 1, -sy * tx, -sy * ty])
    vector = [value for point in source for value in point]

    # Gaussian elimination with partial pivoting.
    size = 8
    for column in range(size):
        pivot = max(range(column, size), key=lambda r: abs(matrix[r][column]))
        matrix[column], matrix[pivot] = matrix[pivot], matrix[column]
        vector[column], vector[pivot] = vector[pivot], vector[column]
        head = matrix[column][column]
        if abs(head) < 1e-12:
            raise ValueError("degenerate perspective quad")
        for row in range(column + 1, size):
            factor = matrix[row][column] / head
            if factor == 0:
                continue
            for k in range(column, size):
                matrix[row][k] -= factor * matrix[column][k]
            vector[row] -= factor * vector[column]

    result = [0.0] * size
    for row in reversed(range(size)):
        total = vector[row] - sum(matrix[row][k] * result[k] for k in range(row + 1, size))
        result[row] = total / matrix[row][row]
    return result


def _tilted_device(framed_path: Path, target_width: int):
    """The phone, turned a few degrees and set back, the way a hand would hold it."""
    device = Image.open(framed_path).convert("RGBA")
    height = int(device.height * (target_width / device.width))
    device = device.resize((target_width, height), Image.LANCZOS)

    # Draw the bottom edge in, so the phone leans away from the viewer rather than
    # standing flat against the panel.
    inset = device.width * HERO_PERSPECTIVE
    source = [(0, 0), (device.width, 0),
              (device.width - inset, device.height), (inset, device.height)]
    target = [(0, 0), (device.width, 0), (device.width, device.height), (0, device.height)]
    device = device.transform(
        device.size, Image.PERSPECTIVE, _perspective_coeffs(source, target),
        Image.BICUBIC, fillcolor=(0, 0, 0, 0)
    )
    return device.rotate(HERO_TILT, resample=Image.BICUBIC, expand=True)


def compose_hero(framed_path: Path, out_path: Path, tagline: str, locale: str):
    """The opening slide: wordmark, one promise, and the app held at an angle."""
    canvas = Image.new("RGBA", CANVAS, PALETTE["hero_panel"])
    draw = ImageDraw.Draw(canvas)

    logo = Image.open(LOGO).convert("RGBA")
    logo_width = int(CANVAS[0] * HERO_LOGO_WIDTH_RATIO)
    logo = logo.resize((logo_width, int(logo.height * (logo_width / logo.width))), Image.LANCZOS)
    canvas.alpha_composite(logo, ((CANVAS[0] - logo_width) // 2, HERO_LOGO_TOP))

    size = HERO_CJK_TAGLINE_SIZE if locale in CJK_LOCALES else HERO_TAGLINE_SIZE
    font = load_font(locale, size)
    y = HERO_LOGO_TOP + logo.height + HERO_TAGLINE_GAP
    for line in tagline.split("\n"):
        box = draw.textbbox((0, 0), line, font=font)
        draw.text(((CANVAS[0] - (box[2] - box[0])) / 2 - box[0], y), line,
                  font=font, fill=PALETTE["hero_ink"])
        y += (box[3] - box[1]) + HERO_TAGLINE_SPACING

    # Anchored under the tagline and allowed to run off the bottom, rather than
    # anchored to the bottom edge: rotating with expand=True pads the image with
    # transparency, so a bottom anchor moves with the tilt instead of with the phone.
    device = _tilted_device(framed_path, int(CANVAS[0] * HERO_DEVICE_WIDTH_RATIO))
    canvas.alpha_composite(device, ((CANVAS[0] - device.width) // 2, y + HERO_DEVICE_GAP))

    out_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(out_path, "PNG")


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
    hero_sources = {}
    for shot in shots:
        locale = shot.parent.name
        stem = shot.stem                      # e.g. "00_dubRecord"
        index, screen = (stem.split("_", 1) + [stem])[:2]
        if not index.isdigit():
            index, screen = "0", stem

        if screen == HERO_SOURCE:
            hero_sources[locale] = shot

        caption = captions.get(screen, {}).get(locale)
        if caption is None:
            missing.append(f"{locale}/{screen}")
            caption = ""

        # Shifted up one: the hero takes slot 00, so the product shots start at 01.
        out_name = f"{int(index) + 1:02d}_{screen}.png"
        out_dir = args.out_dir / LOCALE_DIRS.get(locale, locale)
        compose(shot, out_dir / out_name, caption, locale)
        count += 1

    for locale, source in sorted(hero_sources.items()):
        tagline = captions.get("hero", {}).get(locale)
        if tagline is None:
            missing.append(f"{locale}/hero")
            continue
        out_dir = args.out_dir / LOCALE_DIRS.get(locale, locale)
        compose_hero(source, out_dir / f"{HERO_NAME}.png", tagline, locale)
        count += 1

    if not hero_sources:
        print(f"!!  no '{HERO_SOURCE}' capture found, so no hero slide was built",
              file=sys.stderr)

    print(f"==> {count} App Store screenshots ({CANVAS[0]}x{CANVAS[1]}) in {args.out_dir}")
    if missing:
        # Loud, because a silently blank caption looks like a design choice.
        print(f"!!  no caption for: {', '.join(missing)}", file=sys.stderr)


if __name__ == "__main__":
    main()
