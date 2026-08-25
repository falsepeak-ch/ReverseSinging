#!/usr/bin/env python3
"""
Cuts a dub pack out of a public-domain film.

Run from the repo root:

    python3 Tools/DubPacks/build_clip_pack.py <source-video> <output-dir> [scene ...]

`source-video` is one downloaded film; the scenes below name the stretches of it worth
dubbing and where every line falls inside it.

This is the sibling of `build_pack.py` and it exists because the two jobs are opposites.
`build_pack.py` writes a scene: it lays out invented dialogue on a timeline and then has a
picture generated to match. Here the scene already exists on film — the words, the timing and
the mouths saying them were recorded together in 1951 — so there is nothing to synchronise.
The work is only to *find* the lines and cut them out without moving anything.

That is the whole argument for this route. A generated pack can drift out of sync because the
soundtrack and the picture are produced by different models; a pack cut from one recording
cannot, because a single strip of film is the only thing either of them came from.

Three consequences worth knowing before adding a scene:

  * **Timestamps are the film's, not ours.** A line's chunk starts `LEAD_IN` before the actor
    speaks and the pack timestamp is that instant measured from the top of the scene. Play the
    chunk there and it sits exactly where the picture put it, because it *is* the picture's
    audio.
  * **Every line is one person.** The reference is a mono optical track; two characters
    talking at once cannot be split into two chunks, so scenes with overlapping dialogue are
    not usable and the unison trick `build_pack.py` supports has no equivalent here.
  * **Size is the constraint that bites.** These ship inside the app download. Everything
    below is tuned for bytes: the picture is denoised before encoding because film grain is
    expensive to compress and carries nothing, and the reference chunks are cut at a rate
    chosen from the soundtrack's measured bandwidth rather than by habit.
"""

import json
import math
import os
import re
import struct
import subprocess
import sys
import wave

# What the reference chunks are written at.
#
# Chosen from the source, not from habit. Measured across this film's soundtrack, everything
# above 5 kHz sits 31 dB below the programme and everything above 6 kHz sits 36 dB below it —
# it is a 1951 optical mono track and there is simply nothing up there. 11.025 kHz puts Nyquist
# at 5.5 kHz, which discards only that, and `DubAudioLoader` resamples every chunk to the
# canonical 44.1 kHz on load anyway. The chunks are the largest thing in the pack, so this is
# also the single biggest saving available: a third off, for content nobody can hear.
REFERENCE_RATE = 11025

# Handles left around each line, at most.
#
# Shorter than build_pack.py's, and deliberately: there the lead was a run-up for a performer
# reading invented dialogue cold, here the surrounding film is already playing and the cue is
# the picture.
#
# They are also a ceiling rather than a fixed amount, because real conversation does not leave
# room for them. Where two lines are half a second apart the handles are shrunk to share that
# gap, so no two chunks ever overlap: the handle around one line is the *same film audio* as
# the handle around its neighbour, and two files carrying it would play the identical waveform
# twice at once.
LEAD_IN = 0.22
TAIL = 0.30

VIDEO_WIDTH = 480
VIDEO_HEIGHT = 360
VIDEO_FPS = 24

# Film grain is noise, and noise is the most expensive thing an encoder can be asked to keep.
# Removing it before encoding costs nothing anyone can see on a phone-sized panel and roughly
# halves the file.
DENOISE = "hqdn3d=4:3:6:4"
VIDEO_CRF = 31


# --------------------------------------------------------------------------- scenes

# Provenance, carried into `_pack_info.ini` so each pack says where it came from and under
# what terms. For a CC BY source that is not decoration: attribution is the licence condition,
# and `authors` is what the library screen puts under the pack title.
SOURCES = {
    "sprite-fright": {
        "film": "Sprite Fright",
        "year": 2021,
        "producer": "Blender Studio",
        "url": "https://studio.blender.org/projects/sprite-fright/",
        "rights": "CC BY 4.0 - https://creativecommons.org/licenses/by/4.0/",
        # Both entries show up under the pack title in the library, which is the only place a
        # user ever sees who a pack is by. CC BY asks for credit reasonable to the medium, so
        # the licence travels with the name rather than sitting only in a file nobody opens.
        "authors": ["Blender Studio", "CC BY 4.0"],
    },
    "the-outsider": {
        "film": "The Outsider",
        "year": 1951,
        "producer": "Centron Productions",
        "url": "https://archive.org/details/Outsider1951",
        # Copyright notice on the title card reads COPYRIGHT MCMLI YOUNG AMERICA FILMS, INC.
        # No renewal is recorded for it; see SCRIPTS.md for how that was checked and how far
        # it goes. A licence would have been better, which is why these are no longer the
        # scenes that ship.
        "rights": "US public domain (copyright not renewed)",
        "authors": ["Centron Productions, 1951"],
    },
}

SCENES = {
    "CampRules": {
        "title": "Camp Rules",
        "source": "sprite-fright",
        "start": 100.30,
        "end": 123.20,
        "icon_shot": "rex",
        # Times are the film's own subtitle cues; `tighten_to_speech` snaps each one onto the
        # delivery it labels. Captions are the subtitles verbatim.
        "lines": [
            (100.71, 104.67, "Rex",   "rex",   "Oy, fungus freak! Make yourself useful and fix the tent."),
            (104.67, 108.92, "Ellie", "ellie", "Oh, a bit of friendly campsite ribbing. Fun."),
            (109.88, 112.58, "Rex",   "rex",   "She wouldn't survive 5 minutes alone in these woods."),
            (112.58, 116.79, "Jay",   "tent",  "Yeah. She's a real weenie that one, innit?"),
            (116.79, 119.00, "Rex",   "rex",   "Oy, Phil! How those sausages coming?"),
            (119.00, 122.46, "Phil",  "bbq",   "Almost ready! Just need a bit more salt..."),
        ],
        "shots": {"rex": 101.6, "ellie": 105.6, "tent": 114.6, "bbq": 120.2},
        "video": {"width": 640, "height": 268, "denoise": None, "crf": 30},
    },
    "MeetTheSprites": {
        "title": "Meet the Sprites",
        "source": "sprite-fright",
        "start": 185.30,
        "end": 237.00,
        "icon_shot": "elder2",
        "lines": [
            (185.62, 186.96, "Victoria", "group",  "We'd be famous!"),
            (186.96, 188.29, "Jay",      "group",  "Get on MTV."),
            (188.29, 189.88, "Phil",     "group",  "I wonder what they taste like."),
            (189.88, 192.50, "Ellie",    "ellie2", "We really shouldn't disrupt their habitat."),
            (192.50, 195.92, "Rex",      "group",  "Right. Sure, sure."),
            (195.92, 197.50, "Elder Sprite", "elder", "Greetings."),
            (197.50, 199.00, "Elder Sprite", "elder", "Welcome, friends."),
            (199.00, 201.21, "Elder Sprite", "elder", "I'll be right down."),
            (206.25, 208.75, "Elder Sprite", "path",  "Could I interest you in some peppermint tea?"),
            (208.75, 210.67, "Ellie",    "ellie2", "What are you guys?"),
            (210.67, 214.42, "Elder Sprite", "path", "We are Sprites. We sprite balance to the forest."),
            (214.42, 219.67, "Elder Sprite", "path", "We take care of the animals, plants, birds, moss..."),
            (221.00, 223.92, "Ellie",    "ellie2", "Guys? Guys, I..."),
            (226.58, 231.54, "Rex",      "group",
             "Hey, uh, little mushroom geezer, you cool with us camping here for the night?"),
            (231.54, 236.33, "Elder Sprite", "elder2",
             "Absolutely. A friend of the forest is a friend of the sprites."),
        ],
        "shots": {"group": 186.3, "ellie2": 190.8, "elder": 196.6, "path": 207.0, "elder2": 232.3},
        "video": {"width": 640, "height": 268, "denoise": None, "crf": 30},
    },
}


# ---------------------------------------------------------------------------- audio


def read_wav_mono(path):
    with wave.open(path, "rb") as w:
        rate = w.getframerate()
        frames = w.readframes(w.getnframes())
    return rate, list(struct.unpack("<%dh" % (len(frames) // 2), frames))


def cut_line_audio(source, start, end, out_path):
    """Lifts one line straight out of the film's own soundtrack.

    No processing beyond the resample: this is the performance the picture was shot to, and
    anything done to it here would be a difference between what the performer hears and what
    they can see being said.
    """
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-ss", "%.3f" % start, "-to", "%.3f" % end,
         "-i", source, "-vn", "-ac", "1", "-ar", str(REFERENCE_RATE),
         "-sample_fmt", "s16", "-c:a", "pcm_s16le", out_path],
        check=True,
    )


# What the loudest moment in a scene is lifted to.
#
# Left a little under full scale: the chunks are resampled to 44.1 kHz on load, and
# reconstruction overshoots a sample that already sits at the ceiling.
PEAK_TARGET = 0.85


def normalise_scene(paths):
    """Lifts a whole scene by one gain, chosen from its loudest moment.

    An optical track off a 1951 print arrives around -12 dBFS, which is quiet enough that the
    performer strains to hear the delivery they are copying. The fix has to be one gain for the
    scene rather than a peak per file: normalising each chunk on its own would flatten a
    murmured line and a shouted one into the same loudness, and the difference between them is
    the performance — it is also the thing the delivery score measures.
    """
    peak = 0
    for path in paths:
        _, samples = read_wav_mono(path)
        peak = max(peak, max((abs(s) for s in samples), default=0))

    if peak == 0:
        return 1.0

    gain = (PEAK_TARGET * 32767) / peak
    if gain <= 1.0:
        return 1.0

    for path in paths:
        rate, samples = read_wav_mono(path)
        louder = [max(-32768, min(32767, int(round(s * gain)))) for s in samples]
        with wave.open(path, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(rate)
            w.writeframes(struct.pack("<%dh" % len(louder), *louder))

    return gain


def tighten_to_speech(source, start, end, floor=0.22):
    """Trims a subtitle cue inward onto the delivery it labels.

    Subtitle timings are authored for reading, not for cutting: consecutive cues routinely
    share a boundary even when there is a clear pause between the two deliveries. Taken
    literally they leave no room for handles at all, and a chunk would begin on the speaker's
    first consonant.

    So the words come from the subtitles, which are the film's own and therefore correct, and
    the edges are pulled in to where the sound actually is. **Inward only.** An earlier version
    widened each cue first, to catch speech that started early — and on a scored mix, where the
    level never really drops, that let every cue grow until it swallowed its neighbours and the
    chunks overlapped by more than a second. A cue can only ever shrink here, so the timings
    can be no worse than the subtitles they came from.

    `floor` is a fraction of the cue's own loudest moment, which is why it survives a film with
    music underneath: the music is 7-12 dB below the dialogue in these scenes, so the threshold
    lands above it.
    """
    probe = "%s.probe.wav" % os.path.join(os.path.dirname(source) or ".", "._tighten")
    lo = start
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-ss", "%.3f" % start, "-to", "%.3f" % end,
         "-i", source, "-vn", "-ac", "1", "-ar", "8000", "-c:a", "pcm_s16le", probe],
        check=True,
    )
    rate, samples = read_wav_mono(probe)
    os.remove(probe)

    peak = max((abs(v) for v in samples), default=0)
    if peak == 0:
        return start, end

    level = peak * floor
    size = max(1, int(0.02 * rate))
    first = last = None
    for at in range(0, len(samples) - size + 1, size):
        chunk = samples[at:at + size]
        if math.sqrt(sum(v * v for v in chunk) / size) > level:
            if first is None:
                first = at
            last = at + size

    if first is None:
        return start, end

    return lo + first / rate, lo + last / rate


def rms_windows(samples, rate, window=0.25):
    size = max(1, int(window * rate))
    for start in range(0, len(samples) - size + 1, size):
        chunk = samples[start:start + size]
        yield start / rate, math.sqrt(sum(s * s for s in chunk) / size)


def build_bed(source, scene, gaps, out_path, work_dir, gain=1.0):
    """Makes the scene's backing track out of the room the scene was recorded in.

    The pack format wants a bed under the dialogue, and the obvious candidate — the film's own
    audio — is unusable, because the original performances are baked into it and would play
    underneath the take the performer just recorded. So the bed is built from the film's
    *silences* instead: the longest stretch inside the scene where nobody speaks, looped out to
    length and dropped well down. Same room, same optical hiss, none of the words.
    """
    if not gaps:
        raise SystemExit("no gap between lines to take room tone from")

    gap_start, gap_end = max(gaps, key=lambda g: g[1] - g[0])
    tone = os.path.join(work_dir, "tone.wav")
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-ss", "%.3f" % gap_start, "-to", "%.3f" % gap_end,
         "-i", source, "-vn", "-ac", "1", "-ar", "22050", "-c:a", "pcm_s16le", tone],
        check=True,
    )

    length = scene["end"] - scene["start"]
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-stream_loop", "-1", "-i", tone,
         "-t", "%.3f" % length, "-af", "volume=%.3f" % (0.5 * gain),
         "-c:a", "aac", "-b:a", "24k", "-ac", "1",
         out_path],
        check=True,
    )
    os.remove(tone)
    return length


# ---------------------------------------------------------------------------- video


def probe_duration(path):
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "default=nw=1:nk=1", path],
        check=True, capture_output=True, text=True,
    )
    return float(out.stdout.strip())


def video_settings(scene):
    """Encode settings, defaulting to the scanned-film case and overridable per scene.

    A 16 mm print and a CG render want opposite treatment: the print is mostly grain, which
    must be removed before it is paid for; the render has none, and denoising it only softens
    detail that cost nothing to encode in the first place.
    """
    defaults = {"width": VIDEO_WIDTH, "height": VIDEO_HEIGHT, "denoise": DENOISE, "crf": VIDEO_CRF}
    defaults.update(scene.get("video") or {})
    return defaults


def cut_video(source, scene, out_path):
    """Trims the scene out of the film, silent.

    Runs two frames past the scene length. `DubMixer` clamps the exported audio to the video,
    so a picture that ends even fractionally early clips the tail off every export.
    """
    v = video_settings(scene)
    chain = "fps=%d,scale=%d:%d" % (VIDEO_FPS, v["width"], v["height"])
    if v["denoise"]:
        chain += "," + v["denoise"]
    length = scene["end"] - scene["start"] + 2.0 / VIDEO_FPS
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-ss", "%.3f" % scene["start"],
         "-t", "%.3f" % length, "-i", source, "-an",
         "-vf", chain,
         "-c:v", "libx264", "-preset", "slow", "-crf", str(v["crf"]),
         "-pix_fmt", "yuv420p", "-g", str(VIDEO_FPS * 2), "-movflags", "+faststart",
         out_path],
        check=True,
    )
    return probe_duration(out_path)


def grab_still(source, at, out_path, scene):
    """One frame, for the device that cannot decode the video and for the library tile."""
    v = video_settings(scene)
    chain = "scale=%d:-2" % v["width"]
    if v["denoise"]:
        chain += "," + v["denoise"]
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-ss", "%.3f" % at, "-i", source,
         "-frames:v", "1", "-vf", chain, "-q:v", "6", out_path],
        check=True,
    )


# ----------------------------------------------------------------------------- pack


def build(scene_key, source, out_root):
    scene = SCENES[scene_key]
    src = SOURCES[scene["source"]]
    out = os.path.join(out_root, scene_key)
    os.makedirs(out, exist_ok=True)
    work = os.path.join(out_root, ".clip-work")
    os.makedirs(work, exist_ok=True)

    entries = []
    gaps = []
    previous_end = scene["start"]

    # Snap every cue onto the delivery it labels before anything is measured from it.
    all_lines = []
    for start, end, character, shot, caption in scene["lines"]:
        spoken_start, spoken_end = tighten_to_speech(source, start, end)
        all_lines.append((spoken_start, spoken_end, character, shot, caption))

    for position, (start, end, character, shot, caption) in enumerate(all_lines, start=1):
        if start < scene["start"] or end > scene["end"]:
            raise SystemExit("%s line %d falls outside the scene" % (scene_key, position))

        # Never take more than its share of the silence on either side, so chunks stay disjoint.
        before = all_lines[position - 2][1] if position > 1 else scene["start"]
        after = all_lines[position][0] if position < len(all_lines) else scene["end"]
        lead = max(0.0, min(LEAD_IN, (start - before) * 0.45))
        tail = max(0.0, min(TAIL, (after - end) * 0.45))

        # The chunk, and where it sits measured from the top of the scene. Both come from the
        # film's own clock, which is why the result is in sync without anything being aligned.
        chunk_start = max(scene["start"], start - lead)
        chunk_end = min(scene["end"], end + tail)
        timestamp = chunk_start - scene["start"]

        slug = "%03d_%s" % (position, re.sub(r"[^A-Za-z0-9]+", "_", character))
        cut_line_audio(source, chunk_start, chunk_end, os.path.join(out, slug + ".wav"))

        with open(os.path.join(out, slug + ".txt"), "w") as f:
            f.write("[data]\n")
            f.write('dub_timestamps = [%.3f]\n' % max(0.0, timestamp))
            f.write('dub_characters = ["%s"]\n' % character)
            f.write('caption = "%s"\n' % caption.replace('"', '\\"'))
            f.write('image = "shot_%s.jpg"\n' % shot)

        if start - previous_end > 0.5:
            gaps.append((previous_end + 0.15, start - 0.15))
        previous_end = end

        entries.append((slug, timestamp, chunk_end - chunk_start, character, shot, caption))

    # One gain for the scene, applied to the chunks and to the bed underneath them so the
    # two stay in the relationship the film recorded them in.
    gain = normalise_scene([os.path.join(out, slug + ".wav") for slug, _, _, _, _, _ in entries])

    for shot, at in scene["shots"].items():
        grab_still(source, at, os.path.join(out, "shot_%s.jpg" % shot), scene)

    used = {shot for _, _, _, _, shot, _ in entries}
    missing = used - set(scene["shots"])
    if missing:
        raise SystemExit("%s: no still defined for shot(s) %s" % (scene_key, ", ".join(sorted(missing))))

    bed_length = build_bed(source, scene, gaps, os.path.join(out, "_backing_track.m4a"), work, gain)
    video_length = cut_video(source, scene, os.path.join(out, "dub_video.mp4"))

    icon = "shot_%s.jpg" % scene["icon_shot"]
    if not os.path.exists(os.path.join(out, icon)):
        raise SystemExit("%s: icon_shot %r has no still" % (scene_key, scene["icon_shot"]))

    with open(os.path.join(out, "_pack_info.ini"), "w") as f:
        f.write("[pack]\n")
        f.write('title = "%s"\n' % scene["title"])
        f.write('authors = [%s]\n' % ", ".join('"%s"' % a for a in src["authors"]))
        f.write('icon = "%s"\n' % icon)
        f.write('source = "%s (%d), %s"\n' % (src["film"], src["year"], src["producer"]))
        f.write('source_url = "%s"\n' % src["url"])
        f.write('rights = "%s"\n' % src["rights"])

    if video_length < bed_length - 0.01:
        raise SystemExit("%s: video %.2fs is shorter than the scene %.2fs"
                         % (scene_key, video_length, bed_length))

    total = sum(os.path.getsize(os.path.join(out, f)) for f in os.listdir(out))
    print("\n%s — %d lines, %.1fs, video %.1fs, %d KB on disk (scene gain %+.1f dB)"
          % (scene["title"], len(entries), bed_length, video_length, total // 1024,
             20 * math.log10(gain)))
    cast = []
    for _, _, _, character, _, _ in entries:
        if character not in cast:
            cast.append(character)
    print("   cast: %s" % ", ".join(cast))
    for slug, timestamp, duration, character, shot, caption in entries:
        print("   %-14s %-7s %6.2f → %6.2f  %-8s %s"
              % (slug, character, timestamp, timestamp + duration, shot, caption[:46]))

    return out


if __name__ == "__main__":
    source, out_root = sys.argv[1], sys.argv[2]
    wanted = sys.argv[3:] or list(SCENES)
    for key in wanted:
        build(key, source, out_root)
