#!/bin/sh

# Crashlytics symbol upload for Xcode Cloud, the counterpart to upload_dsyms! in
# fastlane/Fastfile. Bitcode is gone, so App Store Connect never hands Google the
# dSYMs. Whichever machine archives the build is the only thing that can send them,
# and when that machine is Xcode Cloud rather than a laptop running `fastlane beta`,
# this script is the only route. Without it a 1.5.0 crash arrives as raw addresses.

set -e

# Xcode Cloud runs this after every xcodebuild action, including test and build-only
# workflows. Only an archive has dSYMs worth sending.
if [ "$CI_XCODEBUILD_ACTION" != "archive" ]; then
    echo "Not an archive action ($CI_XCODEBUILD_ACTION). No symbols to upload."
    exit 0
fi

GSP_PATH="$CI_PRIMARY_REPOSITORY_PATH/ReverseSinging/GoogleService-Info.plist"
DSYM_PATH="$CI_ARCHIVE_PATH/dSYMs"

# Firebase comes in through SPM, not CocoaPods, so upload-symbols ships inside the
# package checkout rather than a Pods directory. Same path the Fastfile pins, just
# rooted at the derived data Xcode Cloud picked instead of ./build/DerivedData.
UPLOAD_SYMBOLS="$CI_DERIVED_DATA_PATH/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/upload-symbols"

if [ ! -x "$UPLOAD_SYMBOLS" ]; then
    # The checkout directory takes its name from the repository, so this should hold,
    # but a rename upstream would otherwise turn into a silently unsymbolicated build.
    # `|| true` so a find that fails outright does not trip `set -e` and exit without
    # printing anything. The check below is what should report the problem.
    UPLOAD_SYMBOLS=$(find "$CI_DERIVED_DATA_PATH/SourcePackages/checkouts" \
        -name upload-symbols -type f -perm -u+x -print -quit 2>/dev/null || true)
fi

# Never fail the build from here. A missing dSYM folder usually means the archive itself
# already failed (then this error only hides the real one), and a Crashlytics hiccup must
# not block an otherwise good upload. Warn loudly instead; symbols can be re-sent later
# from the archive Xcode Cloud keeps as an artifact.
warn() {
    echo "warning: $1"
    echo "warning: skipping the Crashlytics dSYM upload; the build is not failed for this."
    exit 0
}

if [ -z "$CI_ARCHIVE_PATH" ] || [ ! -d "$CI_ARCHIVE_PATH" ]; then
    warn "no archive at '$CI_ARCHIVE_PATH' (the archive step probably failed)."
fi

if [ ! -d "$DSYM_PATH" ]; then
    warn "the archive at $CI_ARCHIVE_PATH has no dSYMs directory."
fi

if [ ! -x "$UPLOAD_SYMBOLS" ]; then
    warn "upload-symbols not found under $CI_DERIVED_DATA_PATH/SourcePackages/checkouts (it ships inside the firebase-ios-sdk SPM checkout)."
fi

if [ ! -f "$GSP_PATH" ]; then
    warn "GoogleService-Info.plist is missing at $GSP_PATH."
fi

# The Release workflow also archives DubloonMac. Same plist as the Fastfile mac lane, mac platform.
if [ "$CI_PRODUCT_PLATFORM" = "macOS" ]; then
    CRASHLYTICS_PLATFORM=mac
else
    CRASHLYTICS_PLATFORM=ios
fi

echo "Uploading dSYMs from $DSYM_PATH to Crashlytics ($CRASHLYTICS_PLATFORM)."
if ! "$UPLOAD_SYMBOLS" -gsp "$GSP_PATH" -p "$CRASHLYTICS_PLATFORM" "$DSYM_PATH"; then
    warn "upload-symbols exited with an error."
fi
echo "dSYM upload complete."
