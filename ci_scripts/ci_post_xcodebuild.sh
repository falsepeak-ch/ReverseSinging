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

# Fail the build rather than ship a release whose crashes are unreadable. That is the
# failure this script exists to prevent, so it must not pass quietly.
if [ ! -x "$UPLOAD_SYMBOLS" ]; then
    echo "error: upload-symbols not found under $CI_DERIVED_DATA_PATH/SourcePackages/checkouts."
    echo "error: it ships inside the firebase-ios-sdk SPM checkout."
    exit 1
fi

if [ ! -d "$DSYM_PATH" ]; then
    echo "error: the archive at $CI_ARCHIVE_PATH has no dSYMs directory."
    exit 1
fi

if [ ! -f "$GSP_PATH" ]; then
    echo "error: GoogleService-Info.plist is missing at $GSP_PATH."
    exit 1
fi

echo "Uploading dSYMs from $DSYM_PATH to Crashlytics."
"$UPLOAD_SYMBOLS" -gsp "$GSP_PATH" -p ios "$DSYM_PATH"
