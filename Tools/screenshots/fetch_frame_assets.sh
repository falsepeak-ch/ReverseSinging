#!/bin/bash
# Downloads the mockuphone.com iPhone frame assets.
# Assets are committed to the repo; run this only to refresh or change device.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMES_DIR="$SCRIPT_DIR/frames"
BASE="https://raw.githubusercontent.com/oursky/mockuphone.com/master"

# iPhone 15 Pro Max is the newest Pro Max mockuphone.com publishes. Its screen
# is 1290x2796 while we capture at 1320x2868 (iPhone 17 Pro Max) — a 0.2%
# aspect difference that frame.py absorbs when it resizes into the screen rect,
# and which is invisible at any real viewing size.
DEVICE_ID="apple-iphone-15-pro-max-natural-titanium"
mkdir -p "$FRAMES_DIR"

echo "Downloading iPhone frame..."
curl -fsSL -o "$FRAMES_DIR/$DEVICE_ID-portrait.png" \
    "$BASE/public/images/mockup_templates/$DEVICE_ID-portrait.png"

echo "Downloading iPhone mask..."
curl -fsSL -o "$FRAMES_DIR/mask-$DEVICE_ID-portrait.png" \
    "$BASE/public/images/mockup_mask_templates/$DEVICE_ID-portrait.png"

echo "Done. Assets in $FRAMES_DIR"
echo "Note: device.json (screen coords) is maintained by hand from"
echo "$BASE/src/scripts/device_info.json — verify coords if the device changes."
