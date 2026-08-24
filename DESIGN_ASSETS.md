# Design assets needed — "cinema editor" direction

Everything here is a **drop-in upgrade**, not a blocker. The redesign ships with SF Symbols
and the icons already in the project; each item below replaces a placeholder and says exactly
what it replaces. Skip anything you don't want — nothing breaks.

**Direction agreed:** whole app, dark-only, near-monochrome. Neutral greys carry the
interface; colour appears only as *state* (red = recording, green = take saved). The existing
flat-3D retro objects stay as the game's personality and supply almost all the colour, so new
icons must match them exactly.

---

## The house style, for reference

New icons must sit beside `cassette`, `microphone`, `radio` and `note` without looking foreign:

| Property | Value |
|---|---|
| Rendering | Flat-3D, soft bevels, matte surfaces, no photorealism |
| Angle | ~3/4 view, rotated slightly left, tilted slightly down |
| Light | Single soft key from upper-left, no cast shadow, no ground plane |
| Palette | Teal `#2F575E`, red `#E8483C`/`#FF5555`, cream `#F5F1E4`, near-black details |
| Canvas | Square, object centred, ~12% padding on the tightest side |
| Background | **Fully transparent** (the current set is transparent PNG) |

> If these were made with a specific tool, prompt or asset pack, send me that and I'll match
> new requests to it rather than describing the style from scratch.

---

## 1. Icons — highest value (P0)

Same style, same palette, transparent PNG at **@1x / @2x / @3x** (512 / 1024 / 1536 px square).
Naming: lowercase-hyphenated, e.g. `clapperboard.png`, `clapperboard@2x.png`, `clapperboard@3x.png`.

| # | Asset | Where it appears | Placeholder today |
|---|---|---|---|
| 1 | **Clapperboard / slate** | Dub mode's identity: header button, empty library state, pack cards without art | SF Symbol `film.stack` |
| 2 | **Film reel** | Export screen, "your dub is ready" moment | SF Symbol `film` |
| 3 | **Studio mic on a boom** | The recording screen (distinct from the existing handheld `microphone`) | existing `microphone` reused |
| 4 | **Headphones** | "Listen to the original" control and the wear-headphones hint | SF Symbol `headphones` |
| 5 | **Film strip (horizontal)** | Timeline / line-list section header, progress rail decoration | plain rule |

**Nice to have (P2):** projector, director's chair, VHS tape, spotlight, megaphone — these would
give the session-complete and achievement moments something better than a symbol.

---

## 2. Lettering (P1)

The app has `lettering` (REVERSO) and `icon-lettering`. Dub mode currently sets its title in the
system face, which reads generically.

- **`dub-lettering`** — the word **DUB** (or "DUB SESSIONS") in the same Eugello-style treatment
  as REVERSO, cream on transparent, @1x/@2x/@3x, roughly 3:1 aspect.

---

## 3. Texture overlays (P1)

These are what make a dark UI read as *cinema* rather than merely dark. All should be subtle
enough to sit at 4–8% opacity.

| Asset | Spec |
|---|---|
| **Film grain** | Seamlessly tileable, 512×512 PNG, greyscale, transparent. Fine grain — visible at 100% but invisible at 6%. |
| **Vignette** | 2048×2048 PNG, black, radial falloff to transparent centre. Used behind the stills. |
| **Scanline / gate weave** *(optional)* | 4×4 tileable PNG for a faint horizontal texture on panels. |

---

## 4. Sound design (P1) — the biggest "game" upgrade

The app currently has haptics but **no sound effects at all**. For a dubbing game these do more
for feel than any visual. Short, dry, no reverb tail. **`.caf` or 44.1 kHz mono `.wav`**, each
under 400 ms unless noted:

| # | Sound | Trigger |
|---|---|---|
| 1 | **Clapper snap** | Record starts on a line — the signature moment |
| 2 | **Soft tape stop** | Record ends |
| 3 | **Mechanical click** | Advancing to the next line |
| 4 | **Reel spin-up** *(~1.5 s)* | Export begins |
| 5 | **Warm chime / projector start** *(~1.5 s)* | Export finished, dub ready to share |
| 6 | **Dull thunk** | Error or an action that isn't allowed |

If you'd rather not source six, **1, 3 and 5 alone** carry most of the effect.

---

## 5. Typography (P2)

Currently `Eugello.ttf` for display, SF for everything else.

- Timecode and counters will use **SF Mono**, which ships with iOS — no asset needed, and it
  already looks the part.
- **Only if** you want a distinct editor voice: a licensed condensed grotesque (Inter Tight,
  Roboto Condensed, Barlow Condensed or similar) as `.ttf`/`.otf`, **with its licence file**.
  Send the licence — I won't add a font to the bundle without one.

---

## 6. A demo pack you own (P2)

Worth flagging as a product matter, not just an asset: the app currently ships with no packs, so
a new user sees an empty library and has to find a pack before anything happens. A small pack
(6–10 lines, ~30 s) built from **footage and audio you own or that is public domain** would
give first-run something to play with immediately.

Shipping the Harry Potter pack inside the binary would make the app a distributor of copyrighted
studio material, which is a different legal position from users importing packs they already
have. Importing stays exactly as it is either way.

---

## Status — everything requested was delivered and is wired in

| Asset | Status | Where it appears |
|---|---|---|
| `clapperboard` | **Live** | Dub entry point in both main-view toolbars, dub library empty state |
| `dub-lettering` | **Live** | Dub library navigation title, matching the REVERSO lockup |
| `film-reel` | **Live** | Spins while the export renders |
| `film-grain` | **Live** | Tiled at 5–6% over every dark canvas and the stills |
| `vignette` | **Live** | Behind every full-bleed still (recorder and program monitor) |
| `clapper-snap` | **Live** | Record arms — plays *before* the mic opens, so it never lands in the take |
| `tape-stop` | **Live** | Take ends |
| `mechanical-click` | **Live** | Line advance, sound toggled on |
| `reel-spin-up` | **Live** | Export begins |
| `projector-chime` | **Live** | Export finished; also the reverse-singing reveal |
| `error-thunk` | **Live** | Errors in both flows |

### Delivered but not yet placed

These arrived as extras beyond the request and are sitting in the catalogue unused:
`studio-mic-boom`, `headphones`, `film-strip`, `projector`, `directors-chair`,
`vhs-tape`, `spotlight`, `megaphone`, `scanline`.

They're deliberately unplaced rather than forced in. The design rule that emerged is that
the flat-3D icons carry **identity** moments (entry points, empty states, the render
ritual) while dense functional controls stay on SF Symbols — mixing the two inside a
transport row makes both look wrong. Good homes for them when the surfaces exist:

- `studio-mic-boom` / `headphones` — a "wear headphones" first-run tip before dubbing
- `film-strip` — decoration on the line-list section rule
- `projector` / `spotlight` — an export-complete celebration screen
- `directors-chair` / `vhs-tape` / `megaphone` — achievements, or per-pack category art
- `scanline` — a panel texture, currently too strong against the hairline borders

### Still open

- **A demo pack you own** (P2 in the original list). The library is still empty on first
  run until the user imports something.
- **A reference editor screenshot**, if you want the look pushed further in a particular
  direction — still the cheapest way to settle the remaining judgement calls.
