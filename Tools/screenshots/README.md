# App Store screenshots and app preview

Everything on the Reverso product page, generated from the real app: eight screenshots
and one 29-second preview video, in each of the seven store languages. 63 files, one
command each.

```bash
Tools/screenshots/run.sh        # 49 screenshots  -> fastlane/screenshots/<locale>/NN_<screen>.png
Tools/screenshots/record.sh     # 7 preview videos -> fastlane/screenshots/<locale>/00_preview.mp4
```

Then upload them — two lanes, because they take two different paths:

```bash
bundle exec fastlane upload_screenshots   # deliver
bundle exec fastlane upload_previews      # spaceship, direct
```

`deliver` has no app-preview support at all; it scans the screenshots folder for images
only, and a video sitting next to them is ignored without a word. `upload_previews` talks
to the App Store Connect API itself. The App Store shows previews before stills, which is
why the video is named `00`.

## How it works

Four stages, the first two shared with `record.sh`:

| stage | file | what it does |
|---|---|---|
| simulator | `lib.sh` | creates/boots a dedicated simulator, builds, installs onto a clean container, warms up |
| capture | `capture.sh` | one cold launch per screen per locale, `simctl io screenshot` |
| frame | `frame.py` | drops each capture into a mockuphone.com iPhone bezel, on transparency |
| compose | `compose.py` | bezel + localized headline onto a 1320×2868 canvas, plus the hero slide, straight into `fastlane/screenshots/` |

The app poses itself. `ReverseSinging/Support/ScreenshotMode.swift` — all of it behind
`#if DEBUG` — reads `-screenshotMode` and `-screenshotDestination` out of the launch
arguments, skips onboarding, routes to the requested screen, seeds takes against the
first bundled scene, and puts a finished reverse-singing session on screen. Nothing
taps anything, so every locale gets the identical frame.

The preview video is the same idea taken further: `runScreenshotTour()` in
`DubPackDetailView` walks the dub game from the library to a finished render on a fixed
beat sheet (`ScreenshotMode.Tour`), while `simctl io recordVideo` runs.

## The palette is the store's, not the app's

The app is dark-only — `ContentView` forces `.dark`, because a light UI washes out the
stills and waveforms it exists to display. The product page is not.

`PALETTE` in `compose.py` is sampled from the 1.2.0 screenshots that were already on the
App Store: cream `#F8F4D3`, slate-teal ink `#2E4245`, and `#253A3F` for the hero panel.
A dark listing was tried first and looked like a different product next to everything
else Cluso ships. Continuity with what shoppers have already seen is worth more here than
matching the interface behind the glass — the phone in each shot is dark regardless, and
that is where the app's own palette belongs.

The one borrowed accent is `#E5484D`, the record red, as a short rule under each headline.

## The hero slide

Slot `00` is not a captured screen. `compose_hero()` builds it: the `icon-lettering`
lock-up straight out of `Assets.xcassets`, a three-line promise from the `hero` entry in
`captions.json`, and the `dubRecord` capture given a small perspective and a 4.5° tilt so
it reads as a phone being held rather than a rectangle pasted on a panel.

Everything captured therefore shifts up one: `capture.sh` writes `00_dubRecord.png`, and
`compose.py` emits it as `01_dubRecord.png`. Eight slots used of Apple's ten.

The perspective transform solves its own 8×8 system in `_perspective_coeffs` rather than
pulling in numpy — it is the only linear algebra in the pipeline, and the venv is
otherwise just Pillow.

## Its own simulator

`lib.sh` creates a device called **Reverso Screenshots** and uses only that one. This is
not fussiness. A simulator you develop on accumulates state — packs imported while
testing, takes recorded against them — and all of it renders into the library shot with
no way to tell from the outside that it does not belong there. An earlier version of this
script picked "whichever iPhone is available" and produced a set of screenshots showing
two scenes that were never meant to leave the machine.

The app is uninstalled before each run for the same reason: the only scenes that may
appear are the two the app itself ships.

## Adding or changing a screen

1. Add a case to `ScreenshotDestination` in `ScreenshotMode.swift`, and whatever pose it
   needs in the view that owns it.
2. Add the id to `SCREENS_ALL` in `capture.sh`, in the position it should occupy on the
   product page. The `NN` prefix comes from that list's index, so a partial run
   (`--screens home`) still writes the right slot.
3. Add a caption for all seven locales to `captions.json`. A missing one prints to stderr
   rather than quietly composing a blank headline.

## Flags

```bash
run.sh --locales en,ja          # subset
run.sh --screens dubRecord      # subset
run.sh --skip-build             # reuse the last build
run.sh --raw-only               # capture, don't frame
run.sh --frame-only             # re-frame and compose what's already captured
record.sh --locales en
```

`--frame-only` is the one to reach for when iterating on captions or the canvas: it skips
the simulator entirely and takes a few seconds.

## Device frames

`frames/` holds an iPhone 15 Pro Max bezel and its alpha mask from
[oursky/mockuphone.com](https://github.com/oursky/mockuphone.com), plus a hand-maintained
`device.json` with the screen rectangle. `fetch_frame_assets.sh` refetches them; they are
committed, so it is only needed to change device.

15 Pro Max is the newest Pro Max that project publishes. Its screen is 1290×2796 against
our 1320×2868 capture — a 0.2% aspect difference `frame.py` absorbs in the resize, and
which is invisible at any real size.

## Constraints worth not rediscovering

- **6.9" only.** The app is `TARGETED_DEVICE_FAMILY = 1`, portrait — one screenshot set,
  no iPad, no landscape. 1320×2868 is what the iPhone 17 Pro Max simulator captures.
- **Previews are 15–30 seconds.** `record.sh` records 38 and trims to a hard 29. One frame
  over and App Store Connect rejects the upload, and it will not trim for you.
- **The preview must carry a stereo audio track, even a silent one.** `simctl` cannot
  capture the app's own audio, so the track is `anullsrc` silence — but it has to be there.
  Without it App Store Connect accepts every byte and then fails processing with
  `MOV_RESAVE_STEREO`, visible only by reading the asset's delivery state back. That is
  what the verification step in `upload_previews` exists to catch.
- **Previews and screenshots are different frame sizes.** Screenshots go up at 1320×2868;
  previews must be 1290×2796 or 886×1920. `record.sh` scales and crops to the former.
- **Uploading a preview is slow and flaky.** Each locale is a multi-megabyte asset upload
  plus a wait on Apple's processing — 7 to 100 minutes each in practice — and system Ruby's
  OpenSSL drops the connection often enough that a re-run is normal. The lane is idempotent:
  it clears the locale's preview set before uploading, so re-running only redoes what failed.
- **`recordVideo` needs SIGINT**, not SIGKILL. Anything harsher leaves an unfinalised,
  unplayable file.
- **`set -o pipefail` is on.** `find` on a directory the app has not created yet exits
  non-zero and takes the script with it; the warm-up loop wraps those in `{ ...; || true; }`.
- Bash 3.2 is the macOS default: no namerefs, and `${#array[@]}` on an empty array is an
  error under `set -u`. Hence the `RESULT_SCREENS`/`RESULT_COUNT` globals.

## Output

`output/` and `fastlane/screenshots/**` are gitignored — regenerate rather than commit.
The device frames and `captions.json` are committed.

One trap: the previews live in `fastlane/screenshots/<locale>/` alongside the stills, so
`rm -rf fastlane/screenshots` to force a clean compose takes them with it. `compose.py`
overwrites the PNGs it owns and leaves everything else alone, so the wipe is never needed.
If it happens anyway, the raw captures survive in `output/preview/*_raw.mov` and the
trimming step at the end of `record.sh` rebuilds the MP4s in about a minute — no need to
re-record.
