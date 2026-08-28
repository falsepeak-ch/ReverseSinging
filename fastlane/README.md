fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

Generate device-framed, upload-ready App Store screenshots (local only)

Options: locales:en,ja screens:dubRecord,home skip_build:true frame_only:true raw_only:true

### ios preview

```sh
[bundle exec] fastlane ios preview
```

Record the App Store app preview video, one per locale (local only)

Options: locales:en,ja skip_build:true

### ios download_current

```sh
[bundle exec] fastlane ios download_current
```

Download the screenshots currently live on the App Store, into fastlane/live/

Read-only. nothing is written to App Store Connect. Use it to diff before uploading.

### ios metadata

```sh
[bundle exec] fastlane ios metadata
```

Upload metadata only (no binary, no screenshots)

### ios upload_screenshots

```sh
[bundle exec] fastlane ios upload_screenshots
```

Upload screenshots and app previews only

### ios upload_previews

```sh
[bundle exec] fastlane ios upload_previews
```

Upload the App Store app preview videos

Separate from upload_screenshots because `deliver` has no app-preview support at all ,

it scans the screenshots folder for images only. This talks to the API directly.

### ios upload_all

```sh
[bundle exec] fastlane ios upload_all
```

Upload metadata and screenshots

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build and upload a build to TestFlight

### ios release

```sh
[bundle exec] fastlane ios release
```

Build and upload to App Store with metadata and screenshots (does not submit for review)

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
