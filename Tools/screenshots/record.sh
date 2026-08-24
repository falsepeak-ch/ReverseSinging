#!/bin/bash
# Records the App Store app preview video, once per locale.
#
# The app drives itself: ScreenshotMode's `tour` destination walks the dub game from
# the library to a finished render (see runScreenshotTour in DubPackDetailView), so
# every locale gets the identical 30 seconds without anything having to tap.
#
# Usage:
#   Tools/screenshots/record.sh                    # every locale
#   Tools/screenshots/record.sh --locales en,ja
#   Tools/screenshots/record.sh --skip-build
#
# Output: fastlane/screenshots/<App Store locale>/00_preview.mp4
#
# `deliver` uploads video files sitting in the screenshots folder as app previews, and
# the App Store shows previews before stills — so this is the first thing on the product
# page in every language, which is what it is named 00 for.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/output"
DERIVED_DATA="$OUTPUT_DIR/DerivedData"

# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

LOCALES="en,es,ca,fr,it,ja,pt-PT"
SKIP_BUILD=0

# The tour is ~28s of app plus the cold launch. Record longer than that and trim to
# a hard 29s: Apple rejects anything past 30, and the trim is not something App Store
# Connect will do for you.
RECORD_SECONDS=38
FINAL_SECONDS=29

# App previews take a different frame size from screenshots.
#
# 1320x2868 is a valid *screenshot* size for the 6.9" slot and not a valid *preview*
# size — Apple accepts 1290x2796 or 886x1920 there, and App Store Connect drops anything
# else without saying so. The capture is 1320x2868, so it is scaled by width and the two
# spare rows are cropped; the aspect difference is 0.24%.
PREVIEW_WIDTH=1290
PREVIEW_HEIGHT=2796

while [[ $# -gt 0 ]]; do
    case "$1" in
        --locales)    LOCALES="$2"; shift 2 ;;
        --skip-build) SKIP_BUILD=1; shift ;;
        -h|--help)    grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "unknown flag: $1 (see --help)" >&2; exit 1 ;;
    esac
done

locale_region() {
    case "$1" in
        en) echo "en_US" ;; es) echo "es_ES" ;; ca) echo "ca_ES" ;; fr) echo "fr_FR" ;;
        it) echo "it_IT" ;; ja) echo "ja_JP" ;; pt-PT) echo "pt_PT" ;;
        *)  echo "${1}_${1}" ;;
    esac
}

store_locale() {
    case "$1" in
        en) echo "en-US" ;; es) echo "es-ES" ;; fr) echo "fr-FR" ;; *) echo "$1" ;;
    esac
}

# --- Simulator ---------------------------------------------------------------
select_simulator

build_app
prepare_app

# --- Record ------------------------------------------------------------------
RAW_DIR="$OUTPUT_DIR/preview"
mkdir -p "$RAW_DIR"
IFS=',' read -ra LOCALE_LIST <<< "$LOCALES"

for locale in "${LOCALE_LIST[@]}"; do
    region=$(locale_region "$locale")
    raw="$RAW_DIR/${locale}_raw.mov"
    out_dir="$REPO_ROOT/fastlane/screenshots/$(store_locale "$locale")"
    mkdir -p "$out_dir"
    final="$out_dir/00_preview.mp4"

    echo "==> Recording $locale"
    rm -f "$raw"
    xcrun simctl io "$UDID" recordVideo --codec h264 --force "$raw" &
    RECORDER=$!
    sleep 2

    xcrun simctl launch "$UDID" "$BUNDLE_ID" \
        -screenshotMode YES -screenshotDestination tour \
        -hasCompletedOnboarding YES -dubContentGate.hasConfirmedOwnership YES \
        -hapticsEnabled NO \
        -AppleLanguages "($locale)" -AppleLocale "$region" > /dev/null

    sleep "$RECORD_SECONDS"

    # SIGINT, not SIGKILL: recordVideo finalises the container on interrupt and leaves
    # an unplayable file on anything harsher.
    kill -INT "$RECORDER" 2>/dev/null || true
    wait "$RECORDER" 2>/dev/null || true
    xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
    sleep 1

    # Trim the launch and the tail, force 30fps, and strip audio.
    #
    # No audio: the simulator does not capture the app's own output, so the track would
    # be silence — and a preview with a silent track reads as broken where one with no
    # track at all reads as deliberate.
    echo "    trimming -> $(basename "$final")"
    # -ss 2.8 drops the cold launch: the simulator paints a white window before the
    # app's first frame, and a preview opening on white reads as a crash.
    ffmpeg -y -loglevel error -ss 2.8 -i "$raw" -t "$FINAL_SECONDS" \
        -an -c:v libx264 -profile:v high -pix_fmt yuv420p -r 30 -crf 20 \
        -vf "scale=${PREVIEW_WIDTH}:-2,crop=${PREVIEW_WIDTH}:${PREVIEW_HEIGHT}" \
        -movflags +faststart "$final"
done

xcrun simctl status_bar "$UDID" clear || true

echo ""
echo "Done. App previews in fastlane/screenshots/<locale>/00_preview.mp4"
ffprobe -v error -show_entries format=duration -show_entries stream=width,height \
    -of default=noprint_wrappers=1 "$REPO_ROOT/fastlane/screenshots/en-US/00_preview.mp4" 2>/dev/null || true
