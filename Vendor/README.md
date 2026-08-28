# Vendored decoders

## XiphTheora.xcframework

libogg 1.3.5 + libtheora 1.1.1 (decoder only), built for iOS device and simulator.

Dub packs ship their scene as `dub_video.ogv` — Ogg Theora, which AVFoundation cannot
decode. `TheoraTranscoder` uses this framework to convert that file to H.264 once, at
import time, after which everything downstream is plain AVFoundation.

**Why these libraries and not FFmpeg:** both are BSD-3-Clause (see the LICENSE files
next to this README), so static linking carries no source-disclosure obligation. FFmpeg
is LGPL and the available iOS builds are static archives, which would have obliged us to
ship relinkable object files with the app. This is also about 300x smaller — 108 KB for
the device slice against roughly 35 MB for a static libavcodec — because it decodes one
format rather than a thousand.

Only the decoder is compiled in. The encoder half is stubbed out through libtheora's own
`encoder_disabled.c`, which exists for exactly this purpose.

### Rebuilding

    ./Vendor/build-xiph.sh <dir-with-unpacked-sources> Vendor/XiphTheora.xcframework

where the directory contains `libogg-1.3.5/` and `libtheora-1.1.1/` unpacked from
https://downloads.xiph.org/releases/. The script needs only Xcode's clang — no autotools,
no Homebrew packages. Bump `MINVER` in it if the app's deployment target moves.
