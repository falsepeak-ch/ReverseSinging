# Starter Dub Packs

Two scenes ship with the app, so a new player can dub something the minute they open the
mode instead of having to go and find a pack first.

Both are cut from ***Sprite Fright*, Blender Studio, 2021** — an open movie released under
**CC BY 4.0**.

| Pack | Runtime | Lines | Cast | Size |
|---|---|---|---|---|
| **Camp Rules** | 22.9 s | 6 | Rex, Ellie, Jay, Phil | 0.97 MB |
| **Meet the Sprites** | 51.7 s | 15 | Victoria, Jay, Phil, Ellie, Rex, Elder Sprite | 2.08 MB |

`Tools/DubPacks/build_clip_pack.py` builds them. The scene definitions — every line's in and
out point, who says it, which shot it is on — live at the top of that file.

---

## Rights

> **CC BY 4.0** — <https://creativecommons.org/licenses/by/4.0/>
> *Sprite Fright* (2021), Blender Studio — <https://studio.blender.org/projects/sprite-fright/>

This is a licence granted by the rights holder, not an expired copyright, and that distinction
is the whole reason these replaced the earlier scenes. An expiry has to be *proven*, one
jurisdiction at a time; a licence simply is, everywhere the app ships. Confirmed in two
independent places: the licence field on the film's Internet Archive item, and Wikimedia
Commons, which reviews licences before it will host a file.

**The condition is credit, and credit has to be visible.** Each pack carries
`authors = ["Blender Studio", "CC BY 4.0"]`, which is what the library screen prints under the
pack title — the one place a user ever sees who a pack is by. The full statement is in each
pack's `_pack_info.ini` as `source`, `source_url` and `rights`.

**Not every Blender open movie can be used this way.** The newer titles — *Agent 327*,
*Wing It!*, *Coffee Run* — are **CC BY-ND**, which forbids distributing an adaptation, and
cutting a scene into a dub pack is exactly that. *Cosmos Laundromat* is BY-**SA**, which would
push share-alike onto whatever it is combined with. Check the specific film, not the studio.

### Content

The film is a horror-comedy rated around PG-13, and it contains language and cartoon gore that
these packs must not. Both scenes come from the clean first half, and the official subtitles
were used to *screen* the film as well as to caption it: every window here is bounded away from
"piss break" at 95 s, "bloody hell" and "shagged" at 159–162 s, and everything from the horror
turn at 287 s onward. If a third scene is added, read the subtitle file first.

---

## Why film, and not a written scene

The app used to ship two invented scenes with generated voices and generated pictures. The
problem was structural: the soundtrack and the picture came from different models, so nothing
made the mouths agree with the words.

A film does not have that problem. The words, the timing and the mouths saying them were
finished together, so a pack cut from one is in sync because there is a single recording and
both halves are it.

What it costs:

* **No two characters ever speak at once.** A finished stereo mix cannot be split into one
  chunk per speaker. The written scenes each had a deliberate unison line to show the mixer's
  separate lanes off; that has no equivalent here — see `starterPackChunksNeverOverlap`.
* **The reference chunks carry the score.** There is no way to recover a music-and-effects
  track from a finished mix. This one is centre-heavy, so even mid/side cancellation takes the
  music out along with the voices — measured, the side signal drops 10–16 dB in passages with
  no dialogue at all. What saves it is that the score sits only 7–12 dB under the dialogue in
  these two scenes, so a chunk is still dominated by the voice. It is not a clean voice stem,
  and the delivery score is comparing against something noisier than dry dialogue would be.
* **The cast names are the film's; the line attributions are ours.** Blender credits the roles —
  Ellie, Rex, Victoria, Jay, Phil, Elder Sprite — but not who says which line. Speakers were
  assigned by reading the frame at each cue. One line in *Camp Rules* ("She's a real weenie
  that one, innit?") is spoken off-screen and is attributed by inference.

---

## What makes a stretch of film worth cutting

1. **Short lines.** 1.5–3.5 seconds. A performer can hold a short line in their head and hit
   the mark; a long one turns into reading aloud, and reading aloud is not a performance.
2. **Big swings between neighbouring lines.** A murmur followed by a shriek is fun to perform
   and gives the delivery score something real to measure.
3. **Trivial stakes, enormous conviction.**
4. **A punchline near the end.**
5. **A conversation, not a monologue.** `aStarterSceneIsAConversation` guards it.
6. **Everyone on screen when they speak.** An insert cutaway is good film grammar and a dead
   dub cue — the performer has nothing to hit.
7. **A dry soundtrack, if the choice is available.** Dialogue without a score under it makes a
   cleaner pack, for the reason above.

---

## How they are built

```
python3 Tools/DubPacks/build_clip_pack.py <source-video> <output-dir> [scene ...]
```

One pass, because nothing needs laying out: a line's chunk is lifted from the film at the
line's own timestamps, and the pack timestamp is that instant measured from the top of the
scene. Sync is a property of the source, not something the script arranges.

**Captions come from the film's own subtitles.** The release MKV carries official SubRip tracks
in nine languages; the English one is the caption text here, verbatim. That removes the one
real weakness of cutting from film — a machine transcript guessing at the words.

**Timings come from the soundtrack, not the subtitles.** Subtitle cues are authored for
reading: consecutive cues routinely share a boundary even where there is an obvious pause
between deliveries, which would leave no room for handles at all. So each cue is trimmed
*inward* onto where the sound actually is. Inward only — an earlier version widened each cue
first, to catch speech starting before its cue, and on a scored mix, where the level never
really drops, every cue grew until it swallowed its neighbours and chunks overlapped by more
than a second.

The backing track is the film's own quietest stretch inside the scene, looped out to length and
dropped down. The full audio cannot be the bed: the original performances are in it, and the
export is *bed + the user's takes*, so every export would have the original cast talking over
the user.

### Size

Together **3.05 MB**, against 6.92 MB for the generated scenes they replace.

| | Camp Rules | Meet the Sprites |
|---|---|---|
| video (640×268) | 478 KB | 1,192 KB |
| reference chunks | 415 KB | 759 KB |
| backing track | 70 KB | 158 KB |
| stills | 60 KB | 100 KB |

* **The chunk sample rate is chosen from the source**, not by habit — 11.025 kHz here.
  `DubAudioLoader` resamples everything to 44.1 kHz on load anyway.
* **Denoising is off for this source and on for scanned film.** Grain is the most expensive
  thing an encoder can be asked to keep; a CG render has none, and denoising it only softens
  detail that cost nothing. `video_settings` makes that per-scene.
* **Handles are a ceiling, not a fixed amount.** Where two lines sit close together the lead
  and tail shrink to share the gap, so chunks stay disjoint and no silence is paid for twice.

The picture is 2.39:1, which the app letterboxes (`videoGravity = .resizeAspect`). Cropping to
16:9 would reclaim height but cut characters out of the group shots, which is where most of
these scenes' faces are.

---

## The other routes

`Tools/DubPacks/build_pack.py` builds a pack from written dialogue with generated audio and
pictures. It is the right tool for a scene that has to be *written* — an original cast, a joke
that has to land in seven languages — and the wrong tool for a scene that already exists.

`build_clip_pack.py` still carries the scene definitions for **The Outsider** (Centron, 1951),
which shipped briefly. That route works and those packs were good, but it rests on a US-only
finding that no copyright renewal was registered — an absence to be evidenced rather than a
permission that was granted, and the first pass at evidencing it got two things wrong.
`PD_SHORTLIST.md` records what and why.
