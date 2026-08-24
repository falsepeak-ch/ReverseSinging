#!/usr/bin/env python3
"""
Generates the two record-countdown tones.

The countdown is three tones: `count-beep` twice, then `count-beep-go`. The last one
is a fifth higher and a little longer so the downbeat is unmistakable without the
performer having to count along.

Matches the rest of Resources/Sounds: mono, 44.1 kHz, 16-bit.

    python3 Tools/make-count-beeps.py
"""

import math
import os
import struct
import wave

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "ReverseSinging", "Resources", "Sounds")


def tone(freq, duration, peak, decay, harmonic=0.18):
    """A plucked sine: fast attack, exponential tail, a touch of second harmonic so it
    reads as an instrument rather than a test signal."""
    attack = 0.004
    release = 0.008
    frames = int(RATE * duration)
    release_frames = int(RATE * release)
    out = []
    for n in range(frames):
        t = n / RATE
        env = min(1.0, t / attack) * math.exp(-t * decay)
        # The exponential tail is still audible at the last sample; without this the file
        # ends on a step and the beep clicks.
        remaining = frames - n
        if remaining < release_frames:
            env *= remaining / release_frames
        s = math.sin(2 * math.pi * freq * t) + harmonic * math.sin(4 * math.pi * freq * t)
        out.append(s / (1 + harmonic) * env * peak)
    return out


def write(name, samples):
    path = os.path.join(OUT, name)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(
            struct.pack("<h", max(-32768, min(32767, int(s * 32767)))) for s in samples
        ))
    print(f"wrote {path} ({len(samples) / RATE:.3f}s)")


# A5, short and dry — this one plays twice and must not outstay the 0.6s beat.
write("count-beep.wav", tone(880.0, 0.12, peak=0.62, decay=26.0))

# E6, a fifth up and fuller: the downbeat. Recording opens the moment it releases.
write("count-beep-go.wav", tone(1318.51, 0.16, peak=0.78, decay=17.0))
