# Design assets not currently shipped

These imagesets were generated for the "cinema editor" direction (the brief lives in
`Local/docs/DESIGN_ASSETS.md`, which is not tracked. see `.gitignore`) but
nothing in the app references them today. They were moved out of `ReverseSinging/Assets.xcassets`
so they stop costing every user **16.7 MB** of download for features that do not exist yet.

They are kept rather than deleted because they are finished artwork in the house style, and
the brief earmarks several for planned work. `directors-chair`, `vhs-tape` and `spotlight`
for achievements or per-pack category art, for instance.

## Putting one back

Move its `.imageset` folder into `ReverseSinging/Assets.xcassets/images/` and reference it by
name, e.g. `Image("vhs-tape")`. The asset catalogue is a filesystem-synchronised group, so no
project-file edit is needed.

| Asset | Earmarked for |
|---|---|
| `cassette` | Style reference for the house look |
| `directors-chair` | Achievements, or per-pack category art |
| `dub-mic` | Dub mode iconography |
| `film-strip` | Timeline or scrubber decoration |
| `light-bulb` | Tips or hints |
| `note` | Style reference for the house look |
| `projector` | Playback surfaces |
| `spotlight` | Achievements, or per-pack category art |
| `vhs-tape` | Achievements, or per-pack category art |

Verify before deleting any of these: `grep -rF '"vhs-tape"' ReverseSinging --include='*.swift'`
