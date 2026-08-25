# Theora fixtures

All three are 9-second, 640x480, 15fps Ogg Theora clips used by the dub import tests to
prove the Theora-to-H.264 conversion works on real files rather than stand-ins.

- **test.ogv** — video only. Three colour segments (one per 3 seconds) with a white marker
  sliding left to right and fixed corner blocks, so a converted frame can be checked against
  the source position.
- **test_av.ogv** — the same video remuxed with a Vorbis audio track. A real pack's
  `dub_video.ogv` carries audio alongside the video, and a demuxer that mishandles the second
  stream passes the video-only fixture while failing on every real pack. That gap is why this
  one exists.
- **test_dup.ogv** — the same nine seconds, but the picture is held for four frames at a
  time, so 101 of the 135 frames are *duplicates*: 0-byte packets that repeat the frame
  before them. Both fixtures above draw every frame afresh and so contain none, which is
  exactly how a transcoder that dropped duplicate frames outright shipped green. A real film
  scene padded up to a higher frame rate is full of them — one shipped pack lost 307 frames,
  more than five seconds, and its picture ran that far ahead of the voices.

Regenerate the videos with `Vendor/mkogv.c`, built against libogg + libtheora — see
`Vendor/README.md`. It takes an optional hold length: `mkogv test.ogv` draws every frame,
`mkogv test_dup.ogv 4` holds each picture for four, which is what makes libtheora emit the
duplicate packets. Homebrew's ffmpeg has no Theora *encoder*, which is why that small
generator exists rather than a one-line ffmpeg command. The audio track is added with:

    ffmpeg -i test.ogv -f lavfi -t 9 -i "sine=frequency=440:sample_rate=48000" \
      -map 0:v -map 1:a -c:v copy -c:a vorbis -strict -2 -ac 2 -ar 44100 test_av.ogv
