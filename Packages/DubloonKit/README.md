# DubloonKit

Dubloon's reusable building blocks, taken out of the app so they can be tested on their own and
used again elsewhere. Nothing here knows about a dub pack, a screen, a singleton service, Firebase
or the app's strings. Code that needs one of those stays in the app as a thin extension over what
lives here.

Four libraries, each importable on its own:

| Library | What it holds | Depends on |
|---|---|---|
| `DubAudio` | Loading voice audio into one format, finding speech inside a clip, cleaning and levelling a take, splitting overlapping lines into lanes, the master limiter, the bed balance, cutting a mix to an export's segments, waveform peaks and the live trace, reversing a recording, headphone detection (iOS) | AVFoundation |
| `DubScoring` | `DubScorer` (timing, pacing, delivery of a take against its line), `DubLineScore`, `DubSceneScore`, `DubGrade`, and `AudioSimilarityCalculator` for the reverse-singing game | `DubAudio` |
| `DubCompositing` | `DubBoothFrame` and `DubBoothLayout`: where the scene, the booth and the waveform strip sit in an exported frame | CoreGraphics |
| `DubloonFoundation` | `TrialClock`, `ReviewPromptPolicy`, `LaunchDecision` (a question asked once per install), the `rsClock` timecode formats, `CGSize.rsAspectLabel`, `String.nilIfEmpty` | Foundation |

## Using it

```swift
import DubAudio
import DubScoring

let take = try DubAudioLoader.loadVoiceBuffer(from: takeURL)
DubTakeCleanup.apply(to: take)
DubVoiceLevel.match(take, toReferenceAt: referenceURL)

let score = DubScorer.score(takeURL: takeURL, referenceURL: referenceURL, slug: "004_Dobby", referenceOnset: 0.42)
score?.grade.badge   // "A"
```

The app adds the pack-shaped entry points on top, in `ReverseSinging/Services`:

- `DubScorer+DubLine.swift`: `score(takeURL:referenceURL:line:)`, which takes the onset from the line's speech window.
- `DubBackingBalance+DubPack.swift`: `bedGain(for:in:)` and `dialogueLevel(of:)`, over a pack's reference files and line timings.
- `DubAudioCut+Segments.swift`: `cut(_:to:in:)` for the cut planner's segments. It turns an empty plan into `DubExportError.nothingRecorded`.

The app also adds `DubGrade.title` and `color` in `DubScoreViews.swift`, because words and colours belong to the interface. `ReviewPrompt` shows the store prompt and reports it to analytics when `ReviewPromptPolicy` says the moment has come. `EarlyAdopter` and `BoothCamAnnouncement` answer their first-launch questions through `LaunchDecision`.

Type names are the ones the app always used, so moving them changed no call sites beyond an `import`.

## What stayed in the app, and why

- **The design system:** colours, typography, editor chrome, shadows and motion presets. It is the app's look rather than a utility, `EditorChrome` reaches into `Strings` and `HapticManager`, and moving it would add an import to nearly every view.
- **Anything built on `DubPack` or `DubLine`.** This covers `DubVoiceAlignment`, `DubMixer`, `DubPlayer`, `DubBoothComposer`, `DubWaveOverlay` and `DubScoreStore`. The pack model belongs to the app and to `DubPackKit`.
- **Services built on app singletons.** This covers `AudioRecorder`, `AudioPlayer`, `AudioSessionManager` and `RecordCountdown`, which use `AudioFileManager`, `HapticManager`, `SoundManager` or `CrashReporter`.
- **Analytics and crash reporting.** They would bring Firebase into every package build.

## Layout

```
Sources/
  DubAudio/           Loading/  Analysis/  Processing/  Mixing/  Routing/
  DubScoring/         DubScorer, score model, grade, reverse-game similarity, correlation
  DubCompositing/     DubBoothFrame, DubBoothLayout
  DubloonFoundation/  Policies/  Formatting/
Tests/                One test target per library, mirroring Sources
```

## Testing

```bash
swift test                                                        # macOS, a few seconds
xcodebuild test -scheme DubloonKit-Package -destination 'platform=iOS Simulator,name=iPhone 16'
```

`HeadphoneMonitor` is iOS only (`AVAudioSession`) and has no tests; everything else runs on macOS.

## Keys that must not move

Some values are read by installs that already exist, so they stay exactly where earlier versions put them:

- `trial.startedAt` (`TrialClock.defaultStartKey`)
- `review.appOpenCount`, `review.sharedVideoCount` and `review.lastAskedAtOpenCount` (`ReviewPromptPolicy.Keys.standard`). The open count is also how `EarlyAdopter` recognises an install that predates the paywall.
