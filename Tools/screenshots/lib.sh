#!/bin/bash
# Shared setup for capture.sh and record.sh.

BUNDLE_ID="com.falsepeak.reverse-singing-ios"
SCHEME="ReverseSinging"

# A simulator of our own, created on first run.
#
# Not "whichever iPhone is available": a simulator you develop on accumulates state —
# packs imported while testing, takes recorded against them — and every one of those
# would walk into the App Store artwork. An earlier run of this script produced a dub
# library screenshot showing two scenes that happened to be sitting on the development
# device. A dedicated simulator cannot do that, and it never touches what is on the
# shared ones.
SIM_NAME="Reverso Screenshots"
SIM_TYPE="iPhone 17 Pro Max"        # captures natively at 1320x2868, the 6.9" slot

# Sets UDID.
select_simulator() {
    local existing
    existing=$(xcrun simctl list devices -j | python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data['devices'].items():
    for device in devices:
        if device['name'] == '''$SIM_NAME''' and device.get('isAvailable'):
            print(device['udid']); sys.exit()
")

    if [[ -z "$existing" ]]; then
        echo "==> Creating simulator \"$SIM_NAME\" ($SIM_TYPE)"
        local runtime
        runtime=$(xcrun simctl list runtimes -j | python3 -c "
import json, sys
runtimes = [r for r in json.load(sys.stdin)['runtimes']
            if r.get('isAvailable') and r['platform'] == 'iOS']
if not runtimes:
    sys.exit('error: no available iOS runtime')
print(sorted(runtimes, key=lambda r: [int(p) for p in r['version'].split('.')])[-1]['identifier'])
")
        existing=$(xcrun simctl create "$SIM_NAME" "$SIM_TYPE" "$runtime")
    fi

    UDID="$existing"
    echo "==> Simulator: $SIM_NAME ($UDID)"

    local state
    state=$(xcrun simctl list devices -j | python3 -c "
import json, sys
data = json.load(sys.stdin)
for devices in data['devices'].values():
    for device in devices:
        if device['udid'] == '$UDID':
            print(device['state']); sys.exit()
")
    if [[ "$state" != "Booted" ]]; then
        echo "==> Booting"
        xcrun simctl boot "$UDID"
    fi
    xcrun simctl bootstatus "$UDID" -b > /dev/null
}

build_app() {
    APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/ReverseSinging.app"
    if [[ "${SKIP_BUILD:-0}" != "1" || ! -d "$APP_PATH" ]]; then
        echo "==> Building $SCHEME (Debug, simulator)"
        xcodebuild -project "$REPO_ROOT/ReverseSinging.xcodeproj" \
            -scheme "$SCHEME" \
            -configuration Debug \
            -destination "generic/platform=iOS Simulator" \
            -derivedDataPath "$DERIVED_DATA" \
            build | tail -3
    else
        echo "==> Skipping build (reusing $APP_PATH)"
    fi
}

# Installs the app onto a container with nothing in it, then lets the app fill it.
#
# Uninstall first, deliberately. The scenes on screen have to be the two starter packs
# the app itself ships (DubStarterPacks) and nothing else — those are the only ones
# written for this app and cleared to appear in its artwork. A container carried over
# from a previous run could hold a pack imported by hand, and it would show up in the
# library shot with no way to tell from the outside.
prepare_app() {
    echo "==> Installing app onto a clean container"
    xcrun simctl uninstall "$UDID" "$BUNDLE_ID" 2>/dev/null || true
    xcrun simctl install "$UDID" "$APP_PATH"

    # Both games record, so an ungranted mic would put a system alert in every shot.
    xcrun simctl privacy "$UDID" grant microphone "$BUNDLE_ID" || true

    xcrun simctl status_bar "$UDID" override \
        --time "9:41" --batteryState charged --batteryLevel 100 \
        --cellularBars 4 --operatorName "" || true

    warm_up
}

# One throwaway launch, to get the first-run work out of the way before the camera rolls.
#
# The app installs its starter packs on first open — two zips, unpacked and parsed — and
# ScreenshotMode seeds takes against the first of them. None of that belongs in a
# screenshot, and a scene that is still importing is a progress bar, not a product shot.
warm_up() {
    echo "==> Warming up (installing starter packs, seeding takes)"
    xcrun simctl launch "$UDID" "$BUNDLE_ID" \
        -screenshotMode YES -screenshotDestination dubLibrary \
        -hasCompletedOnboarding YES -dubContentGate.hasConfirmedOwnership YES \
        -hapticsEnabled NO -AppleLanguages "(en)" -AppleLocale en_US > /dev/null

    local container packs takes waited=0
    container=$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data)
    while (( waited < 120 )); do
        # `|| true` inside the group, not after the pipe: `set -o pipefail` is on, and
        # find exits non-zero until the app has created these directories — which is
        # exactly the window this loop exists to wait out.
        packs=$({ find "$container/Documents/DubPacks" -maxdepth 1 -mindepth 1 -type d 2>/dev/null || true; } | wc -l | tr -d ' ')
        takes=$({ find "$container/Documents/DubTakes" -name '*.caf' 2>/dev/null || true; } | wc -l | tr -d ' ')
        if [[ "$packs" -ge 2 && "$takes" -ge 1 ]]; then
            echo "    ready: $packs packs, $takes takes"
            break
        fi
        sleep 1
        waited=$((waited + 1))
    done
    if (( waited >= 120 )); then
        echo "warning: starter packs did not finish installing in 120s" >&2
    fi

    sleep 2
    xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
}
