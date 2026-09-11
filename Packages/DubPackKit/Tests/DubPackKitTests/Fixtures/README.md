# Fixtures

Loaded through `Fixtures.url(_:)` in `Support/TestSupport.swift`. Packs that tests only need to
vary are built on the fly by `PackBuilder` instead; these are the files that cannot be.

## Theora video

All three are 9-second, 640x480, 15 fps Ogg Theora clips that prove the Theora-to-H.264
conversion on real files rather than stand-ins.

- **test.ogv:** video only. Three colour segments, one per 3 seconds, with a white marker sliding
  left to right and fixed corner blocks, so a converted frame can be checked against the source.
- **test_av.ogv:** the same video with a Vorbis audio track. A real pack's `dub_video.ogv` carries
  audio alongside the video, and a demuxer that mishandles the second stream passes the
  video-only fixture while failing on every real pack.
- **test_dup.ogv:** the same nine seconds with each picture held for four frames, so 101 of the
  135 frames are duplicates: 0-byte packets that repeat the frame before them. The fixtures above
  contain none, which is how a transcoder that dropped duplicates shipped green. One real pack
  lost 307 frames that way and its picture ran five seconds ahead of the voices.

Regenerate them with `Vendor/mkogv.c`, built against libogg and libtheora. It takes an optional
hold length: `mkogv test.ogv` draws every frame, `mkogv test_dup.ogv 4` holds each picture for
four. Homebrew's ffmpeg has no Theora encoder, which is why the generator exists. The audio
track is added with:

    ffmpeg -i test.ogv -f lavfi -t 9 -i "sine=frequency=440:sample_rate=48000" \
      -map 0:v -map 1:a -c:v copy -c:a vorbis -strict -2 -ac 2 -ar 44100 test_av.ogv

## Audio

- **line.mp3:** half a second of a 440 Hz tone, the way half the community packs ship their lines.
- **line.ogg:** the same in Ogg Vorbis, which AVFoundation may not decode.

    ffmpeg -f lavfi -i "sine=frequency=440:sample_rate=48000" -t 0.5 -ac 1 -b:a 32k line.mp3
    ffmpeg -f lavfi -i "sine=frequency=440:sample_rate=48000" -t 0.5 -ac 2 -c:a vorbis -strict -2 line.ogg

## 7z archives

Each holds the same two-line pack, `Fixture Pack/`: a `.wav` + `.jpg` line, an `.mp3` + `.png`
line, an `.mp3` backing track, and CRLF text with curly quotes. No 7z tool is needed: macOS's
`bsdtar` writes the format.

- **pack_lzma2.7z, pack_lzma1.7z, pack_ppmd.7z, pack_deflate.7z, pack_bzip2.7z, pack_store.7z:**
  one per compression method, with the pack in a wrapping folder.

      bsdtar -cf pack_lzma2.7z --format 7zip --options 7zip:compression=lzma2 "Fixture Pack"

- **pack_nested.7z:** the pack two folders down, as `release/Fixture Pack/`.
- **pack_flat.7z:** the pack's files at the root of the archive.

      bsdtar -cf pack_flat.7z --format 7zip --options 7zip:compression=lzma2 -C "Fixture Pack" .

- **pack_unsafe_path.7z:** the pack's files at the root plus `../escape.txt`, an entry that climbs
  out of the destination and must be refused. `-P` keeps the `..` in the stored name.

      cd "Fixture Pack" && bsdtar -P -cf ../pack_unsafe_path.7z --format 7zip \
        --options 7zip:compression=lzma2 * ../escape.txt

## Streamed zips

Both hold `Streamed Pack/`, shaped like the Forrest Gump pack that prompted zip recovery: `.ini`
line entries, two characters sharing a number, a `.png` still, no pack info, `icon.jpg`, and the
backing track last. Every entry, stored ones included, keeps its sizes in a data descriptor after
its data, as streaming zip writers do; that is the hardest shape to read without an index. The
damaged variants the tests need (no index, cut off inside an entry, a flipped byte, a bad flag)
are made from `pack_streamed.zip` by `Support/ZipBytes.swift`.

- **pack_streamed.zip:** the intact archive.
- **pack_streamed_unsafe.zip:** the same with `../escape.txt` added after the first entry.

They are written by Python's `zipfile` to a stream it cannot seek, which is what makes it use data
descriptors:

    class Unseekable:
        def __init__(self, f): self.f = f
        def write(self, b): return self.f.write(b)
        def flush(self): self.f.flush()

    with open("pack_streamed.zip", "wb") as raw, zipfile.ZipFile(Unseekable(raw), "w") as archive:
        for name, data, method in entries:   # .ini and one .mp3 deflated, everything else stored
            info = zipfile.ZipInfo(name, date_time=(2026, 9, 10, 19, 47, 0))
            info.compress_type = method
            archive.writestr(info, data)

