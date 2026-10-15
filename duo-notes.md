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

## Pose design (2026-10-15, v2)
Containers: ArrangementView (iOS 27.1) for the library split and booth panes, size classes plus a measured width for "wide enough", no device checks. State lives in view models, so a pose change only moves geometry.
- Closed / outer (compact): unchanged. Library pushes the detail; booth is one column.
- Open portrait (book): Library = packs list | selected pack detail with hero, equal panes so the fold falls between them. Booth = picture above, desk (waveform, line, transport) below, at an even 0.5 split.
- Open landscape: Library = same list | detail split. Booth = studio: picture about 62% wide, desk as a full-height column beside it (waveform top, line at eye level, transport at the bottom).
- Half-folded tabletop: booth picture above the fold for viewing at a distance, desk below in reach (system split, 0.5 vertical ratio). Library keeps its panes; scrolling content does not displace.
- Half-folded book: library list and detail on either side of the fold.
- Selection carries across: opening the device moves a pushed pack into the detail pane; closing pushes the selected pack again. Reduce Motion turns off the layout and selection animations; the booth picture uses matchedGeometry between layouts.
- Accessibility sizes: home and library drop to one column; pack cards stack the still above the text instead of clipping it.
- Narrow regular windows (iPad Stage Manager, under 700 pt): no split, plain list; large home rows only from 900 pt.
- Hero: 380 pt top-anchored on regular, clipped so the vignette does not bleed into the status strip.
- Not verified on device: which axis the system picks in each fold pose, and the exact ratio semantics of `splitArrangementLayoutRatio`.
