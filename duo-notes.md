# iPhone Duo redesign notes
Journey: Home (modes) → Movie Scene Dub library → Pack detail → Record ; Reverse Singing
Stack: SwiftUI, iOS 17.0 target, iPhone only + Mac target, Xcode 27.1 / iOS 27.1 SDK, iPhone Duo simulator
Stage: 5  Next: inner display run in Device Hub; Booth Cam on a device (camera)

## Findings
- Home / Library: Change — one stretched column at any width [T466]; now two-up on regular width (even count, fold clear) [HIG]
- TimerCard: Change — `UIScreen.main` width [T461]
- Custom header bars (?, settings, +): Decision — app-drawn, stay horizontal [T462]
- Pack detail hero video: Ready (mixed) — full-width media, controls inset [HIG]
- Booth Cam (front camera): Decision — Virtual Front Camera / rotation coordinator per T465; needs a physical iPhone Duo, not done
- Orientation: portrait only; inner display ignores it [T461]

## Decisions
- Inner display: recommended width reflow (2-up cards); chosen (agent, 2026-10-15)
- Camera adoption: deferred until device testing (agent, 2026-10-15)

## Done / verified
- 2-up reflow + fixed timer label width — iOS and DubloonMac build (run); outer display 5 screens (run); iPhone 17 library unchanged (run); inner not run

## Pose design (2026-10-15)
- Closed / outer: unchanged iPhone layouts (one column, compact). Nothing moves.
- Open portrait: Home and Library use larger rows/cards (2-up, even columns, fold clear), Home menu centred vertically; pack detail hero 380 pt, top-anchored so faces stay in frame.
- Open landscape: same as portrait; hero clipped to the safe area so the vignette no longer bleeds into the trailing status strip.
- Half-folded tabletop: Record booth sits in a vertical split `ArrangementView` (iOS 27.1). Scene picture + HUD are the primary (above the fold, viewable at a distance); waveform, subtitle line, score and transport are the secondary (below the fold, in reach). System handles the fold, no hard-coded positions.
- Half-folded book: booth split is limited to the vertical axis, so it stays one column and the system keeps the fold clear; no side-by-side jump.
- Not done yet: list + detail split for the library (needs a NavigationSplitView restructure), pose-transition animation polish, per-pose previews.
