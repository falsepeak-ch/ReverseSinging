# Design asset generation manifest

Generated from `DESIGN_ASSETS.md` on 2026-08-22.

## Object icon prompt set

The ten object masters were generated with the built-in image generation tool using the app-icon microphone plus the existing cassette, radio, and note PNGs as style references.

Common prompt:

> Use case: stylized-concept. Asset type: iOS app UI icon, square transparent PNG master. Match the references closely: polished flat 3D toy-object render, chunky rounded bevels, matte surfaces, clean simplified geometry, subtle ambient occlusion, restrained soft highlights, no outlines. Center one object on a square canvas in a three-quarter view rotated slightly left and viewed slightly from above, with about 12% clear padding. Use one soft key from upper left. Palette: deep teal #2F575E, coral red #E8483C/#FF5555, warm cream #F5F1E4, and near-black recessed details. Require genuine transparency and a clean small-size silhouette. No floor, ground plane, cast shadow, glow, scenery, border, text, letters, or watermark.

Subjects:

- `clapperboard`: classic cinema slate with its striped hinged top slightly open.
- `film-reel`: five-spoke vintage reel with a short curled film tail.
- `studio-mic-boom`: condenser microphone in a shock mount on a compact articulated boom arm.
- `headphones`: over-ear studio headphones with thick cushions and a gently arched headband.
- `film-strip`: short horizontal five-frame 35 mm film strip, gently curved in depth.
- `projector`: compact vintage two-reel movie projector with a short lens barrel.
- `directors-chair`: classic folding director's chair with fabric seat and back.
- `vhs-tape`: retro VHS cassette with two windows and a broad blank label.
- `spotlight`: theatrical Fresnel spotlight on a yoke stand with four barn doors.
- `megaphone`: handheld director's megaphone with a flared bell, handle, and trigger.

Any generated checkerboard backdrop was removed in a separate background-extraction pass that preserved the object unchanged and replaced only the backdrop with genuine transparency.

## Deterministic supporting assets

- `dub-lettering` was rendered from the bundled `Eugello.ttf` in #F5F1E4 on transparency.
- `film-grain` is a mirrored-edge 512 px grayscale noise tile with a 48% alpha channel.
- `vignette` is a 2048 px black radial alpha falloff from 0% in the center to 78% at the edge.
- `scanline` is a seamless 4 px tile with one 20%-alpha black row.

## Sound cues

The six WAV files are original procedural synthesis at 44.1 kHz mono, with no sampled source material:

- `clapper-snap.wav` — 220 ms
- `tape-stop.wav` — 380 ms
- `mechanical-click.wav` — 100 ms
- `reel-spin-up.wav` — 1.5 s
- `projector-chime.wav` — 1.5 s
- `error-thunk.wav` — 280 ms
