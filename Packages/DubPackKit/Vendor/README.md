# Vendored decoders

## XiphCodecs.xcframework

libogg 1.3.5 + libvorbis 1.3.7 (with vorbisfile) + libtheora 1.1.1 (decoder only), as static
libraries for iOS devices, the iOS simulator and macOS.

Dub packs ship their scene as `dub_video.ogv`, Ogg Theora, and half of them ship their lines and
backing track as `.ogg`, Ogg Vorbis; AVFoundation decodes neither. `TheoraTranscoder` converts the
video to H.264 and `AudioTrackConverter` the audio to AAC, once, at install time, after which
everything downstream is plain AVFoundation. The macOS slice exists so both are tested by
`swift test` on a Mac, without a simulator.

**Why these libraries and not FFmpeg:** both are BSD-3-Clause (see the LICENSE files next to this
README), so static linking carries no source-disclosure obligation. FFmpeg is LGPL and the
available iOS builds are static archives, which would have obliged us to ship relinkable object
files with the app. This is also about 300x smaller, because it decodes one format rather than a
thousand.

Only the decoders are compiled in. libtheora's encoder half is stubbed out through its own
`encoder_disabled.c`, which exists for exactly this purpose; libvorbis's encoder API
(`vorbisenc.c`) and its standalone tuning tools are left out of the build.

The headers sit flat under each slice's `Headers/`, because libtheora's and libvorbis's own
headers include `<ogg/ogg.h>` and `<vorbis/codec.h>`. Xcode copies every static xcframework's headers into one shared `include/`
directory, so do not add a second xcframework to the app with a top-level `module.modulemap`.

### Rebuilding

    ./Vendor/build-xiph.sh <dir-with-unpacked-sources>

where the directory contains `libogg-1.3.5/`, `libvorbis-1.3.7/` and `libtheora-1.1.1/` unpacked from
https://downloads.xiph.org/releases/, checked against the `SHA256SUMS` published there. The script
needs only Xcode's clang: no autotools, no Homebrew packages. Keep `IOS_MINVER` and
`MACOS_MINVER` in step with the platforms in `Package.swift`.

## mkogv.c

Generates the Theora test fixtures in `Tests/DubPackKitTests/Fixtures`. Build it against libogg and
libtheora (including the encoder); see the fixtures README for how each file is made.
