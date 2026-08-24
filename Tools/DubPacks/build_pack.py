#!/usr/bin/env python3
"""
Turns a scene definition into a dub pack folder in the format DubPackParser reads.

Run from the repo root:

    python3 Tools/DubPacks/build_pack.py <raw-audio-dir> <image-dir> <output-dir> [clip-dir]

`raw-audio-dir` holds `<index>.wav` per line and `image-dir` holds `<index>.png` per
shot, both named by the indices in SCENES below. `clip-dir`, when given, holds
`<shot>.mp4` per shot and the pack gets a real scene video cut from them.

The interesting part is `trim_to_speech`. Text-to-speech pads its output with silence,
by a different amount every time, and a pack's line duration is the stretch of film the
performer has to fill — so a line padded with two seconds of nothing would ask them to
hold a two-second pause they cannot hear. Every reference is therefore cut back to its
own speech plus a fixed handle at each end, and the timeline is laid out from the
*measured* result rather than from anyone's estimate.
"""

import math
import os
import re
import struct
import subprocess
import sys
import wave

SAMPLE_RATE = 44100

# What the reference lines are actually written at.
#
# These ship inside the app, so every megabyte is a megabyte of download. Speech carries
# nothing above 11 kHz worth keeping, and `DubAudioLoader` resamples every line to the
# canonical 44.1 kHz on load anyway — so this halves the pack for no audible difference
# and no change to how anything downstream behaves.
REFERENCE_RATE = 22050

# Handles left around the speech in each reference line.
#
# Not zero. The lead gives the performer a beat of run-up to come in on rather than
# having to be talking before the line starts, and the app's own onset detection lines
# their take up against the speech inside it either way. The tail stops a final
# consonant from being clipped by the trim.
LEAD_IN = 0.28
TAIL = 0.42

# Silence between one line's speech and the next, unless the script overrides it.
DEFAULT_GAP = 0.55


# --------------------------------------------------------------------------- scenes

SCENES = {
    "TheLastSlice": {
        "title": "The Last Slice",
        "authors": ["Reverso"],
        "icon_index": 1001,
        "lines": [
            # (index, character, caption, shot, gap-before-this-line)
            (101, "Barnaby", "Nobody has to get hurt here, Pip.", 1001, 0.0),
            (102, "Pip", "You said that about the muffin!", 1003, 0.35),
            (103, "Barnaby", "The muffin was a misunderstanding.", 1002, 0.5),
            (104, "Pip", "You ate it in front of me. Slowly.", 1003, 0.6),
            (105, "Barnaby", "I maintain eye contact. It is manners.", 1002, 0.5),
            (106, "Pip", "That is not manners! That is a threat!", 1004, 0.3),
            (107, "Gary", "Fellas.", 1005, 1.1),        # the beat before the turn
            (108, "Barnaby", "Gary?!", 1006, 0.5),
            (109, "Pip", "Gary!", 1006, "unison"),      # lands on top of line 108
            (110, "Gary", "I have been eating this since Tuesday.", 1005, 0.8),
            (111, "Pip", "Gary. It is Tuesday.", 1003, 0.7),
            (112, "Gary", "Then I am nearly done.", 1007, 0.9),
        ],
    },
    "TheYogurtIncident": {
        "title": "The Yogurt Incident",
        "authors": ["Reverso"],
        "icon_index": 2001,
        "lines": [
            (201, "Diane", "It had my name on it.", 2002, 0.0),
            (202, "Marcus", "Lots of people are called Diane.", 2003, 0.6),
            (203, "Diane", "In this office?", 2002, 0.45),
            (204, "Marcus", "There could be a new Diane.", 2003, 0.55),
            (205, "Diane", "There is no new Diane, Marcus.", 2002, 0.6),
            (206, "Marcus", "I panicked! It was strawberry!", 2004, 0.4),
            (207, "Diane", "It was mango.", 2005, 0.7),
            (208, "Marcus", "Then who ate the strawberry one?", 2003, 0.9),
            (209, "Kevin", "Morning, team! Great yogurt in there.", 2006, 1.0),
            (210, "Diane", "Kevin.", 2007, 0.8),
            (211, "Marcus", "Kevin.", 2007, "unison"),  # lands on top of line 210
        ],
    },
}


# ---------------------------------------------------------------------------- audio


def read_wav_mono(path):
    """Reads any wav into mono float samples at SAMPLE_RATE, via ffmpeg."""
    converted = path + ".conv.wav"
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", path,
         "-ac", "1", "-ar", str(SAMPLE_RATE), "-sample_fmt", "s16", converted],
        check=True,
    )
    with wave.open(converted, "rb") as w:
        frames = w.readframes(w.getnframes())
    os.remove(converted)

    count = len(frames) // 2
    return list(struct.unpack("<%dh" % count, frames))


def write_wav_mono(path, samples, rate=SAMPLE_RATE):
    clipped = [max(-32768, min(32767, int(s))) for s in samples]
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(struct.pack("<%dh" % len(clipped), *clipped))


def downsample(samples, factor):
    """Averages `factor` samples into one. Crude, and entirely adequate for speech that
    is about to be resampled back up by AVFoundation on load."""
    out = []
    for start in range(0, len(samples) - factor + 1, factor):
        out.append(sum(samples[start:start + factor]) / factor)
    return out


def speech_bounds(samples, window=0.02, threshold=0.04):
    """First and last window whose RMS clears `threshold` of the clip's own peak.

    Deliberately the same measurement `DubSpeechOnset` makes in the app, so a line
    trimmed here and the speech window the parser measures at import agree.
    """
    peak = max((abs(s) for s in samples), default=0)
    if peak == 0:
        return None

    level = peak * threshold
    size = max(1, int(window * SAMPLE_RATE))
    first = last = None

    for start in range(0, len(samples) - size + 1, size):
        chunk = samples[start:start + size]
        rms = math.sqrt(sum(s * s for s in chunk) / size)
        if rms > level:
            if first is None:
                first = start
            last = start + size

    return None if first is None else (first, last)


def trim_to_speech(samples):
    """Cuts a clip back to its speech plus the fixed handles, padding if it is short."""
    bounds = speech_bounds(samples)
    if bounds is None:
        return samples

    first, last = bounds
    lead = int(LEAD_IN * SAMPLE_RATE)
    tail = int(TAIL * SAMPLE_RATE)

    start = first - lead
    end = last + tail

    head = [0] * max(0, -start)
    foot = [0] * max(0, end - len(samples))
    body = samples[max(0, start):min(len(samples), end)]

    return head + body + foot


def room_tone(duration, seed=7):
    """A very quiet, slowly wandering bed, so the scene has continuity between lines.

    Written rather than generated: it is a filtered hiss with a slow swell, which is
    all a dialogue bed needs to be, and it keeps the pack free of anyone else's music.
    """
    total = int(duration * SAMPLE_RATE)
    out = [0.0] * total

    state = 0.0
    rng = seed
    for i in range(total):
        # Cheap deterministic LCG — the same pack builds byte-identical every time.
        rng = (1103515245 * rng + 12345) & 0x7FFFFFFF
        white = (rng / 0x3FFFFFFF) - 1.0
        # One-pole low pass: hiss becomes air.
        state = state * 0.995 + white * 0.005
        swell = 0.7 + 0.3 * math.sin(2 * math.pi * i / (SAMPLE_RATE * 11.0))
        out[i] = state * swell

    loudest = max((abs(s) for s in out), default=0) or 1.0
    return [s / loudest * 0.035 * 32767 for s in out]


# ----------------------------------------------------------------------------- video

# What the scene video is encoded at.
#
# It plays in a phone-sized frame inside the app, so 540p is already more than the panel
# can show — and the file ships inside the download, where every megabyte is real.
VIDEO_WIDTH = 960
VIDEO_HEIGHT = 540
VIDEO_FPS = 24


def probe_duration(path):
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "default=nw=1:nk=1", path],
        check=True, capture_output=True, text=True,
    )
    return float(out.stdout.strip())


def assemble_video(entries, clip_dir, scene_length, out_path, work_dir):
    """Cuts the per-shot clips into one continuous scene video.

    The app plays a pack's video straight through and corrects it towards the audio clock,
    and the record screen seeks it to a single line's `startTime`. So the cuts have to fall
    exactly on the line timestamps this same script just wrote — that is the whole reason
    the video is assembled here, from the finished timeline, rather than anywhere else.

    A shot used by several lines is cut from a different part of its clip each time, so a
    character who speaks three times does not visibly replay the same two seconds.
    """
    os.makedirs(work_dir, exist_ok=True)

    # One boundary per distinct start time. Lines spoken in unison share a timestamp and
    # would otherwise produce a zero-length segment between them.
    ordered = sorted({round(start, 3): shot for _, start, _, _, shot in reversed(entries)}.items())
    boundaries = [(start, shot) for start, shot in ordered]

    segments = []
    uses = {}

    for index, (start, shot) in enumerate(boundaries):
        last = index + 1 >= len(boundaries)
        end = scene_length if last else boundaries[index + 1][0]
        length = round(end - start, 3)

        # The final segment runs a frame or two long. `DubMixer` clamps the exported audio to
        # the video's length, so a video that finishes even fractionally early would clip the
        # tail off every export.
        if last:
            length = round(length + 2.0 / VIDEO_FPS, 3)
        if length <= 0:
            continue

        clip = os.path.join(clip_dir, "%d.mp4" % shot)
        clip_length = probe_duration(clip)

        # Where in the clip to start. Each reuse of a shot steps further in, wrapping so the
        # segment always fits inside the clip.
        seen = uses.get(shot, 0)
        uses[shot] = seen + 1
        headroom = max(0.0, clip_length - length)
        offset = round(min(headroom, seen * 1.3), 3) if headroom > 0 else 0.0

        segment = os.path.join(work_dir, "seg_%03d.mp4" % index)
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error",
             # Looped input so a segment longer than its clip runs on instead of freezing.
             "-stream_loop", "-1", "-ss", "%.3f" % offset, "-i", clip,
             "-t", "%.3f" % length,
             "-an",
             "-vf", "scale=%d:%d:force_original_aspect_ratio=increase,crop=%d:%d,fps=%d"
                    % (VIDEO_WIDTH, VIDEO_HEIGHT, VIDEO_WIDTH, VIDEO_HEIGHT, VIDEO_FPS),
             "-c:v", "libx264", "-preset", "slow", "-crf", "27",
             "-pix_fmt", "yuv420p", "-g", str(VIDEO_FPS * 2),
             segment],
            check=True,
        )
        segments.append(segment)

    listing = os.path.join(work_dir, "segments.txt")
    with open(listing, "w") as f:
        for segment in segments:
            f.write("file '%s'\n" % os.path.abspath(segment))

    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", listing,
         "-c", "copy", "-movflags", "+faststart", out_path],
        check=True,
    )

    for segment in segments:
        os.remove(segment)
    os.remove(listing)

    return probe_duration(out_path)


# ----------------------------------------------------------------------------- pack


def slug_for(index, character):
    safe = re.sub(r"[^A-Za-z0-9]+", "_", character).strip("_")
    return "%03d_%s" % (index % 100 if index % 100 else index, safe)


def build(scene_key, raw_dir, image_dir, out_root, clip_dir=None):
    scene = SCENES[scene_key]
    out = os.path.join(out_root, scene_key)
    os.makedirs(out, exist_ok=True)

    entries = []
    shots = set()
    cursor = 0.0
    previous_speech_start = 0.0

    for position, (index, character, caption, shot, gap) in enumerate(scene["lines"], start=1):
        samples = trim_to_speech(read_wav_mono(os.path.join(raw_dir, "%d.wav" % index)))
        duration = len(samples) / SAMPLE_RATE

        slug = "%03d_%s" % (position, re.sub(r"[^A-Za-z0-9]+", "_", character))

        if gap == "unison":
            # Two characters speaking at once: the second line is placed so its *speech*
            # begins where the previous line's speech does, not where its chunk does.
            # The mixer puts them on separate lanes, so both are actually heard.
            start = previous_speech_start - LEAD_IN
        else:
            start = cursor + gap
            previous_speech_start = start + LEAD_IN
            cursor = start + duration

        write_wav_mono(
            os.path.join(out, slug + ".wav"),
            downsample(samples, SAMPLE_RATE // REFERENCE_RATE),
            rate=REFERENCE_RATE,
        )

        # Several lines share a shot — a close-up of whoever is speaking is reused every
        # time they speak. Written once and referenced by name, because twelve copies of
        # seven pictures is most of the pack.
        image_name = "shot_%d.jpg" % shot
        if image_name not in shots:
            subprocess.run(
                ["sips", "-s", "format", "jpeg", "-s", "formatOptions", "78",
                 "-Z", "1280", os.path.join(image_dir, "%d.png" % shot),
                 "--out", os.path.join(out, image_name)],
                check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
            shots.add(image_name)

        with open(os.path.join(out, slug + ".txt"), "w") as f:
            f.write("[data]\n")
            f.write('dub_timestamps = [%.3f]\n' % max(0.0, start))
            f.write('dub_characters = ["%s"]\n' % character)
            f.write('caption = "%s"\n' % caption.replace('"', '\\"'))
            f.write('image = "%s"\n' % image_name)

        entries.append((slug, start, duration, character, shot))

    scene_length = max(start + duration for _, start, duration, _, _ in entries) + 1.2

    # The bed goes out as AAC. `DubPackParser` matches the backing track on its stem and
    # only accepts one AVFoundation can actually read, so the extension is free to be
    # whatever is smallest — and thirty seconds of room tone as raw PCM is three megabytes
    # of an app download to say nothing.
    bed_wav = os.path.join(out, "_bed.wav")
    write_wav_mono(bed_wav, room_tone(scene_length))
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", bed_wav,
         "-c:a", "aac", "-b:a", "48k", os.path.join(out, "_backing_track.m4a")],
        check=True,
    )
    os.remove(bed_wav)

    # The icon is one of the shots the scene already ships, not a fourteenth picture.
    icon = "shot_%d.jpg" % scene["icon_index"]

    with open(os.path.join(out, "_pack_info.ini"), "w") as f:
        f.write("[pack]\n")
        f.write('title = "%s"\n' % scene["title"])
        f.write('authors = [%s]\n' % ", ".join('"%s"' % a for a in scene["authors"]))
        f.write('icon = "%s"\n' % icon)

    if clip_dir:
        length = assemble_video(
            entries, clip_dir, scene_length,
            os.path.join(out, "dub_video.mp4"),
            os.path.join(out_root, ".video-work"),
        )
        print("%s — scene video %.1fs" % (scene["title"], length))

    print("%s — %d lines, %.1fs" % (scene["title"], len(entries), scene_length))
    for slug, start, duration, character, shot in entries:
        print("   %-18s %-9s %6.2f → %6.2f  shot %d" % (slug, character, start, start + duration, shot))

    return out


if __name__ == "__main__":
    raw_dir, image_dir, out_root = sys.argv[1], sys.argv[2], sys.argv[3]
    clip_dir = sys.argv[4] if len(sys.argv) > 4 else None
    for key in SCENES:
        build(key, raw_dir, image_dir, out_root, clip_dir)
