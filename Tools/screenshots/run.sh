#!/bin/bash
# One-command screenshot pipeline: build -> capture every screen -> frame -> compose.
#
# Usage:
#   Tools/screenshots/run.sh                          # full run, all locales
#   Tools/screenshots/run.sh --locales en             # single locale
#   Tools/screenshots/run.sh --screens dubRecord,home
#   Tools/screenshots/run.sh --skip-build             # reuse last build
#   Tools/screenshots/run.sh --frame-only             # re-frame/compose existing raws
#   Tools/screenshots/run.sh --raw-only               # capture only
#
# The app preview video is a separate step — see Tools/screenshots/record.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

LOCALES="en,es,ca,fr,it,ja,pt-PT"
SCREENS=""
SKIP_BUILD=0
FRAME_ONLY=0
RAW_ONLY=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --locales)    LOCALES="$2"; shift 2 ;;
        --screens)    SCREENS="$2"; shift 2 ;;
        --skip-build) SKIP_BUILD=1; shift ;;
        --frame-only) FRAME_ONLY=1; shift ;;
        --raw-only)   RAW_ONLY=1; shift ;;
        -h|--help)    grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "unknown flag: $1 (see --help)" >&2; exit 1 ;;
    esac
done

# Frame assets must exist (committed to the repo; refetch if missing).
if [[ ! -f "$SCRIPT_DIR/frames/device.json" ]]; then
    echo "==> Frame assets missing, fetching..."
    "$SCRIPT_DIR/fetch_frame_assets.sh"
fi

# Python venv for Pillow, created once.
VENV="$SCRIPT_DIR/.venv"
if [[ "$RAW_ONLY" != "1" ]]; then
    if [[ ! -x "$VENV/bin/python3" ]]; then
        echo "==> Creating Python venv with Pillow"
        python3 -m venv "$VENV"
        "$VENV/bin/pip" -q install pillow
    fi
fi

if [[ "$FRAME_ONLY" != "1" ]]; then
    LOCALES="$LOCALES" SCREENS="$SCREENS" SKIP_BUILD="$SKIP_BUILD" "$SCRIPT_DIR/capture.sh"
fi

if [[ "$RAW_ONLY" != "1" ]]; then
    "$VENV/bin/python3" "$SCRIPT_DIR/frame.py"
    "$VENV/bin/python3" "$SCRIPT_DIR/compose.py"
fi

echo ""
echo "Done."
[[ "$FRAME_ONLY" != "1" ]] && echo "  raw:      $SCRIPT_DIR/output/raw/<locale>/"
if [[ "$RAW_ONLY" != "1" ]]; then
    echo "  framed:   $SCRIPT_DIR/output/framed/<locale>/  (device on transparency)"
    echo "  upload:   $REPO_ROOT/fastlane/screenshots/<locale>/  (1320x2868, App Store ready)"
fi
