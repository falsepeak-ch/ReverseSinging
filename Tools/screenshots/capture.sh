#!/bin/bash
# Captures raw simulator screenshots of every registered screen, per locale.
# Driven by run.sh — can also be invoked directly.
#
# Env (set by run.sh):
#   LOCALES   comma-separated (default: en,es,ca,fr,it,ja,pt-PT)
#   SCREENS   comma-separated screen ids (default: all of SCREENS_ALL below)
#   SKIP_BUILD=1 to reuse the last build
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/output"
DERIVED_DATA="$OUTPUT_DIR/DerivedData"

# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

LOCALES="${LOCALES:-en,es,ca,fr,it,ja,pt-PT}"
SKIP_BUILD="${SKIP_BUILD:-0}"

# Screen ids — must stay in sync with ScreenshotDestination in
# ReverseSinging/Support/ScreenshotMode.swift and with captions.json.
# The order here is the order they appear on the App Store product page.
# The leading NN of each output filename is this list's index, so a partial run
# (`--screens home`) still writes 03_home.png and lands in the right App Store slot.
# Format: <id>:<settle-seconds>:<extra launch args>
SCREENS_ALL=(
    "dubRecord:9:"
    "dubDetail:8:"
    "dubExport:8:"
    "home:5:"
    "reverse:6:-uiMode complex"
    "dubLibrary:7:"
    "settings:5:"
)

locale_region() {
    case "$1" in
        en)    echo "en_US" ;;
        es)    echo "es_ES" ;;
        ca)    echo "ca_ES" ;;
        fr)    echo "fr_FR" ;;
        it)    echo "it_IT" ;;
        ja)    echo "ja_JP" ;;
        pt-PT) echo "pt_PT" ;;
        *)     echo "${1}_${1}" ;;
    esac
}

# Applies the --screens filter, if one was given. Bash 3.2 (the macOS default)
# has no namerefs, so the result comes back via the global RESULT_SCREENS.
select_screens() {
    RESULT_SCREENS=()
    RESULT_COUNT=0
    local position=0
    if [[ -n "${SCREENS:-}" ]]; then
        local id entry w
        IFS=',' read -ra WANTED <<< "$SCREENS"
        for entry in "${SCREENS_ALL[@]}"; do
            id="${entry%%:*}"
            for w in "${WANTED[@]}"; do
                if [[ "$id" == "$w" ]]; then
                    RESULT_SCREENS+=("$position:$entry")
                    RESULT_COUNT=$((RESULT_COUNT + 1))
                fi
            done
            position=$((position + 1))
        done
    else
        for entry in "${SCREENS_ALL[@]}"; do
            RESULT_SCREENS+=("$position:$entry")
            position=$((position + 1))
        done
        RESULT_COUNT=${#SCREENS_ALL[@]}
    fi
    # Explicit: the last command above is a failed `[[ ]]` whenever the final
    # candidate doesn't match, and `set -e` would treat that as a fatal error.
    return 0
}

# --- Simulator ---------------------------------------------------------------
select_simulator

# --- Build & install ---------------------------------------------------------
build_app
prepare_app

# --- Capture loop ------------------------------------------------------------
IFS=',' read -ra LOCALE_LIST <<< "$LOCALES"
select_screens
# RESULT_COUNT rather than ${#RESULT_SCREENS[@]}: bash 3.2 (the macOS default)
# errors on empty-array expansion under `set -u`.
if [[ "$RESULT_COUNT" -eq 0 ]]; then
    echo "error: no matching screens for '${SCREENS:-}'" >&2
    exit 1
fi

TOTAL=$(( ${#LOCALE_LIST[@]} * RESULT_COUNT ))
COUNT=0

for locale in "${LOCALE_LIST[@]}"; do
    RAW_DIR="$OUTPUT_DIR/raw/$locale"
    mkdir -p "$RAW_DIR"
    region=$(locale_region "$locale")

    for record in "${RESULT_SCREENS[@]}"; do
        index="${record%%:*}"
        entry="${record#*:}"
        id="${entry%%:*}"
        rest="${entry#*:}"
        settle="${rest%%:*}"
        extra="${rest#*:}"

        COUNT=$((COUNT + 1))
        printf "==> [%d/%d] %s / %s " "$COUNT" "$TOTAL" "$locale" "$id"

        xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
        sleep 1
        # shellcheck disable=SC2086 -- $extra is an intentional arg list
        xcrun simctl launch "$UDID" "$BUNDLE_ID" \
            -screenshotMode YES \
            -screenshotDestination "$id" \
            -hasCompletedOnboarding YES \
            -dubContentGate.hasConfirmedOwnership YES \
            -hapticsEnabled NO \
            -AppleLanguages "($locale)" \
            -AppleLocale "$region" \
            $extra > /dev/null

        sleep "$settle"

        out="$RAW_DIR/$(printf '%02d' "$index")_${id}.png"
        xcrun simctl io "$UDID" screenshot "$out" > /dev/null
        echo "-> $(basename "$out")"
    done
done

xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl status_bar "$UDID" clear || true
echo "==> Raw screenshots in $OUTPUT_DIR/raw/"
