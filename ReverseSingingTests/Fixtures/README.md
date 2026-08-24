# Theora fixtures

Both are 9-second, 640x480, 15fps Ogg Theora clips used by the dub import tests to prove
the Theora-to-H.264 conversion works on real files rather than stand-ins.

- **test.ogv** — video only. Three colour segments (one per 3 seconds) with a white marker
  sliding left to right and fixed corner blocks, so a converted frame can be checked against
  the source position.
- **test_av.ogv** — the same video remuxed with a Vorbis audio track. A real pack's
  `dub_video.ogv` carries audio alongside the video, and a demuxer that mishandles the second
  stream passes the video-only fixture while failing on every real pack. That gap is why this
  one exists.

Regenerate the video with `Vendor/mkogv.c`, built against libogg + libtheora — see
`Vendor/README.md`. Homebrew's ffmpeg has no Theora *encoder*, which is why that small
generator exists rather than a one-line ffmpeg command. The audio track is added with:

    ffmpeg -i test.ogv -f lavfi -t 9 -i "sine=frequency=440:sample_rate=48000" \
      -map 0:v -map 1:a -c:v copy -c:a vorbis -strict -2 -ac 2 -ar 44100 test_av.ogv
