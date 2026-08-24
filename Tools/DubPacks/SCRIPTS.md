# Starter Dub Packs — Scripts

Two original scenes that ship with the app, so a new player can dub something the
minute they open the mode instead of having to go and find a pack first.

Everything here is written for this app and generated for it: original characters,
original dialogue, generated voices and generated pictures. No film, no script, no
performance and no music by anyone else is used, quoted or imitated.

## What makes a scene good to dub

The two scenes below are built against the same checklist, which is worth keeping
if more packs are written later:

1. **Short lines.** 1.5–3.5 seconds. A performer can hold a short line in their head
   and hit the mark; a long one turns into reading aloud, and reading aloud is not
   a performance.
2. **Big swings between neighbouring lines.** A murmur followed by a shriek is fun
   to perform and gives the delivery score something real to measure. A scene at one
   volume scores the same however you read it.
3. **Trivial stakes, enormous performance.** This is the engine of dub comedy: the
   gap between how seriously the scene takes itself and what it is actually about.
   Both scenes are a life-or-death standoff over food.
4. **A punchline in the last three lines.** It is the reason someone shares the
   export, and the reason they record the whole scene rather than the first two lines.
5. **A third character who arrives late.** The turn lands harder, and it gives the
   scene a third voice to do — which is what makes people record it twice.
6. **Two characters speaking at once, at least once.** The mixer puts overlapping
   lines on separate lanes, so it plays back properly, and performing one half of a
   unison line is funny on its own.
7. **No proper nouns anyone owns**, nothing that needs a culture to land, and nothing
   that stops being funny in translation. These ship in seven languages.

---

## Pack 1 — "The Last Slice"

**Style:** cartoon. **Runtime:** ~40 s. **Cast:** 3. **Lines:** 12.

**Setting.** Inside a fridge, 3 a.m. One slice of pizza on a plate, lit from above by
the fridge bulb like a police interrogation. BARNABY, a large, immaculately groomed
cat, and PIP, a small, extremely nervous pigeon, are circling it. Neither has blinked
in some time.

**Voices to aim for.** Barnaby: silky, posh, far too calm. Pip: high, fast, one bad
minute from a breakdown. Gary: impossibly slow, very deep, entirely at peace.

| # | Character | Line | Direction |
|---|-----------|------|-----------|
| 1 | Barnaby | Nobody has to get hurt here, Pip. | Silky. Menacing precisely because it is calm. |
| 2 | Pip | You said that about the muffin! | Cracking. Already too loud. |
| 3 | Barnaby | The muffin was a misunderstanding. | Bored. Waving it away. |
| 4 | Pip | You ate it in front of me. Slowly. | Trembling. Quiet with rage. |
| 5 | Barnaby | I maintain eye contact. It is manners. | Proud of himself. |
| 6 | Pip | That is not manners! That is a threat! | Full shriek. The loudest line in the scene. |
| 7 | Gary | Fellas. | Deep, slow, serene. Arrives from nowhere. |
| 8 | Barnaby | Gary?! | Shocked. Overlaps line 9. |
| 9 | Pip | Gary! | Shocked. Overlaps line 8. |
| 10 | Gary | I have been eating this since Tuesday. | Contented. Mouth full. In no hurry at all. |
| 11 | Pip | Gary. It is Tuesday. | Horrified whisper. |
| 12 | Gary | Then I am nearly done. | Deeply, completely satisfied. |

---

## Pack 2 — "The Yogurt Incident"

**Style:** live action, shot like a thriller. **Runtime:** ~40 s. **Cast:** 3. **Lines:** 11.

**Setting.** An office break room at night, lit by one strip light. DIANE stands
perfectly still. MARCUS is sweating. Between them, on the counter, an empty yogurt pot
with a name written on the lid in marker. The camera pushes in slowly on both of them,
as though something much worse than this is about to happen.

**Voices to aim for.** Diane: glacial, quiet, never raises her voice once. Marcus:
increasingly damp. Kevin: cheerful, oblivious, chewing.

| # | Character | Line | Direction |
|---|-----------|------|-----------|
| 1 | Diane | It had my name on it. | Glacial. Barely above a whisper. |
| 2 | Marcus | Lots of people are called Diane. | A weak deflection he already regrets. |
| 3 | Diane | In this office? | Ice. Four syllables, no mercy. |
| 4 | Marcus | There could be a new Diane. | Desperate. Grasping. |
| 5 | Diane | There is no new Diane, Marcus. | Slow. Final. The quotable one. |
| 6 | Marcus | I panicked! It was strawberry! | Breaking. The confession. |
| 7 | Diane | It was mango. | Quiet. Devastating. |
| 8 | Marcus | Then who ate the strawberry one? | Dawning horror. Very slow. |
| 9 | Kevin | Morning, team! Great yogurt in there. | Cheerful, oblivious, mouth full. |
| 10 | Diane | Kevin. | Deadly. In unison with line 11. |
| 11 | Marcus | Kevin. | Deadly. In unison with line 10. |

---

## How these are built

`Tools/DubPacks/build_pack.py` turns a script definition into a pack folder in the
format `DubPackParser` reads: one `NNN_Character.txt` per line with its timestamp and
caption, a `NNN_Character.wav` of the reference delivery, a `NNN_Character.jpg` still,
and a `_pack_info.ini`.

Line audio and stills are generated, then the script assigns timestamps from the
*measured* length of each generated line rather than from the estimates above — so the
timings in the finished pack are true to the audio that actually shipped.

Each scene also ships `dub_video.mp4`, which is what the picture actually is — the
per-line stills are only the fallback for a device that cannot decode it. One five-second
clip is generated per *shot* (seven for the fridge, six for the break room), animated from
the still that shot already produced so the look stays consistent, and `assemble_video`
cuts those clips into one continuous video whose cuts fall exactly on the line timestamps
this same script just wrote. That is why the video is assembled here and not anywhere
else: the app seeks it by line, and only the code that laid out the timeline knows where
the cuts belong. A shot used by several lines is cut from a different part of its clip each
time, so a character who speaks three times does not replay the same two seconds.
