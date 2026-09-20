# DubPackKit

Imports community dub packs ("mods") for Dubloon: from a folder, a `.zip`, a `.7z` or a `.rar`, in the
shapes packs actually arrive in rather than only the one the format describes, from zips that
did not finish downloading, and from files iCloud has not delivered yet. Media the platform does
not play (Ogg Vorbis audio, Theora video) is converted on the way in. It knows nothing
about the app. It returns plain values and typed errors, and reports what it could not parse
through a protocol the app points at Crashlytics.

## Using it

```swift
import DubPackKit

let installer = DubPackInstaller(
    libraryDirectory: packsFolder,
    ignoredFileNames: ["manifest.json"],   // the host's own cache, never copied from a source
    reporter: myReporter                   // any DubPackIssueReporter
)

let installed = try await installer.install(
    from: pickedURL,
    progress: { progress in
        // progress.stage: .copying, .convertingAudio, .convertingVideo, .reading; fraction 0...1
    },
    beforeCommit: { incoming, destination, pack in
        // Optional: write the host's own files into the pack folder before it replaces the
        // installed one. A throw fails the install and leaves the previous install untouched.
    }
)
installed.pack      // ParsedPack: title, authors, icon, backing track, video, lines, provenance
installed.issues    // [DubPackIssue]: everything that was dropped or worked around
```

`DubPackReader` reads a pack that is already installed. It never reports, so re-reading a pack
on a later launch cannot repeat the non-fatals its import sent. `DubPackRepair` finishes what an
install could not: a Theora conversion the system cut short (the original is kept), or Vorbis
audio installed by a build that did not convert it. Call `hasPendingConversions(in:)` on load.

A failed install throws `DubPackImportError`. It carries no user-facing text: switch over it and
say it in the user's language. A failed re-install leaves the pack already installed under the
same name untouched.

## What a pack may look like

The format as specified is `_pack_info.ini`, then `NNN_Character.txt` + `.jpg` + `.wav` per line,
`_backing_track.mp3` and `dub_video.ogv`, all flat in one folder. All of these variations read too:

| Part | Accepted |
|---|---|
| Where the pack is | Files at the top of the archive, or up to four folders down. `__MACOSX` is ignored. A folder can also be reached through a symbolic link. A file or folder still in iCloud is downloaded first. |
| Archive | `.zip`; `.7z` compressed with LZMA, LZMA2, PPMd, Deflate, BZip2 or stored; `.rar`, RAR 4 and RAR 5, without a password and in one volume. Recognised by their bytes, so a renamed file still opens (the most imported file that would not was a `.rar` called `.zip`), and a `.zip` that is really a web page or an mp3 is refused as one (`looksLike`). |
| Damaged rar | Entries that fail their checksum are left out, and an archive cut off partway keeps every entry before the break. Nothing partial is kept: a RAR entry is one compressed stream. |
| Damaged zip | A zip whose index is missing or refused, typically a cut-off download, is read entry by entry from the front. Entries failing their checksum are left out; a file cut off by the end is kept only if it is audio. |
| Pack info | `_pack_info.ini`, `pack_info.ini`, `_packinfo.ini`, `packinfo.ini`, `_pack_info.txt`, `pack_info.txt`, in any case. Optional: without one, the pack is titled after the folder it came wrapped in, else after the archive or folder name. |
| Line entries | `NN_Character.txt` or `NN_Character.ini`; the `.txt` wins when both exist. Unnumbered text files count when they carry line keys or have a recording of the same name beside them. A file with no keys at all is its own caption. |
| Text encoding | UTF-8 with or without a byte-order mark, UTF-16, Windows-1252. CRLF or LF. |
| Keys | Any case. `key=value` or `key = value`. Quoted, single-quoted or bare values. `#` and `;` comments. |
| Line audio | `.wav`, `.mp3`, `.m4a`, `.aac`, `.aif`, `.caf`, `.flac` and more, beside the entry or named by an `audio` key. The first that decodes wins. `.ogg`/`.oga` Vorbis is converted to `.m4a` at install. |
| Stills | `.jpg`, `.png`, `.heic`, `.webp` and more, named by `image` or beside the entry. A missing still borrows the previous line's. |
| Timestamps | `6.716`, `6,716`, `6.716s`, `1:06.716`, `00:01:06,500` (SRT), `01:06:12:14` (frames dropped), `1m6.5s`, `[6.716]`, `t=6.716`, and the start of a range `6.7-9.2`. Under `dub_timestamps`, `timestamp`, `start` and similar, or in the file name (`01_Cady_12.5.txt`). |
| Character | `dub_characters`, `character`, `speaker`, else taken from the file name (`018_Mr_Dursley` is "Mr Dursley"). |
| Backing track | `_backing_track`, `backing_track`, `backing`, `instrumental` with any audio extension, else the only audio file no line uses. Vorbis is converted to AAC. |
| Scene video | `dub_video`, `video`, `scene` with any video extension, else the only unnumbered video. Theora is converted to H.264; a conversion the system interrupts keeps the original and is retried later. |
| Icon | Named by `icon` (found by stem when the extension is wrong), else `icon.*` or `cover.*`, else any unnumbered image whose name says icon or cover, else the first line's still. |

What still drops a line: no start time, an unreadable start time, or no audio that decodes.

## What gets reported

The installer sends one `DubPackIssueReport` per kind of issue per pack, after the pack is read.
If the install fails, it sends the issues found so far and then one report for the failure. The
`context` and `kind.code` are stable, so a crash reporter can group on them. Keys hold file names
from inside the pack, counts and the pack's own title, never what a line says (the one exception
is `detail_sample`, the raw text of a timestamp that would not parse).

Each report has a `severity`. `.degraded` is content the user lost: dropped lines, media that will
not play, a failed install. `.informational` is something worked around without loss: an icon
found by convention, a title from the folder, a still borrowed from the line before, a video
conversion deferred to a later launch, an install refused because the device is out of storage
or the file has not come down from iCloud. A reporter should send only the first as non-fatals.

| Context | When | Keys besides `pack_title` |
|---|---|---|
| `dub_pack.dropped_lines` | Entries that could not become lines | `dropped_count`, `candidate_count`, `kept_count`, `reasons`, `sample`, `detail_sample` |
| `dub_pack.no_line_entries` | Nothing looked like a line entry, or no pack was found at all | `file_count`, `file_types` (e.g. `ini: 38, jpg: 38`) |
| `dub_pack.extra_timestamps` | Entries with more start times than the one performed | `entry_count`, `sample` |
| `dub_pack.missing_stills` | Entries with no still | `missing_count`, `candidate_count`, `sample` |
| `dub_pack.missing_icon` | The pack info names an icon that is not there | `file_extension` |
| `dub_pack.missing_pack_info` | No pack info under any accepted name | `sample` (other text files) |
| `dub_pack.unreadable_pack_info` | Pack info in no known encoding | `file` |
| `dub_pack.ambiguous_backing_track` | Several unnamed audio files could be the bed | `candidate_count`, `sample` |
| `dub_pack.unplayable_backing_track` | The bed does not decode | `file_extension` |
| `dub_pack.ambiguous_video` | Several unnamed videos could be the scene | `candidate_count`, `sample` |
| `dub_pack.unplayable_video` | The scene video does not decode | `file_extension` |
| `dub_pack.video_transcode` | Theora conversion failed or came out the wrong length, or was deferred | `source_extension`, `failure`, `deferred`, `expected_seconds`, `actual_seconds`, `detail` |
| `dub_pack.audio_transcode` | Vorbis recordings that would not convert | `file_count`, `failures`, `sample`, `detail` |
| `dub_pack.recovered_archive` | A zip was cut off, or had entries failing their checksum | `truncated_entry`, `partial_kept`, `damaged_count` |
| `dub_pack.skipped_archive_entries` | Archive entries pointing outside the pack | `skipped_count` |
| `dub_pack.import` | The install failed | `failure`, `stage`, `source_extension`, `detail`, `environmental` |

Breadcrumbs go to `DubPackIssueReporter.log`: `dub_pack.import began (.7z)`, then `staged`,
`installed`, `converted N vorbis files`, `converted`, `read`, or `failed <code>`.

## Layout

```
Sources/DubPackKit/
  Import/     DubPackInstaller and the steps of an install: staging, finding the pack, installing
  Archives/   Recognising and unpacking .zip, .7z and .rar, and recovering damaged zips
  Reading/    DubPackReader and the format: fields, text encodings, timestamps, file lookup
  Video/      Theora to H.264
  Audio/      Vorbis to AAC
  Media/      The AVFoundation probe for what decodes
  Issues/     DubPackIssue, grouping into reports, the reporter protocol
Sources/CArchives/   In C: the LZMA SDK's 7z decoder and libarchive's RAR readers, each behind a
                     streaming extractor, and the zip recovery
Vendor/              XiphCodecs.xcframework (libogg + libvorbis + libtheora decoders) and its build script
Tests/DubPackKitTests/  Mirrors Sources; fixtures in Fixtures/ (see its README)
```

## Testing

```bash
swift test                                                       # macOS, a few seconds
xcodebuild test -scheme DubPackKit -destination 'platform=iOS Simulator,name=iPhone 16'
DUB_PACK_SAMPLES=~/DubPackSamples swift test --filter RealPackSamplesTests
```

The last one installs every pack in a folder of real community packs (folders, zips and 7zs)
and fails on any issue. The packs stay out of the repository: they are cut from other people's
films.

## Vendored code

- **CArchives:** the `C/` decoder subset of the LZMA SDK 26.03 (public domain, Igor Pavlov) in
  `Sources/CArchives/lzma-sdk`, plus `SevenZipExtract.c`. The SDK only extracts a whole solid
  block into memory; the extractor streams the common single-coder blocks to disk in 256 KB
  steps, checks every CRC, refuses `..` paths, and falls back to the SDK for PPMd and filtered
  blocks with a memory cap. Deflate and BZip2 come from the system's libz and libbz2. To take a
  newer SDK, replace the files in `lzma-sdk/` with the same-named ones from its `C/` folder.
  `ZipRecover.c` is this package's own: it walks a zip's local headers with the system's zlib,
  for archives whose index is gone. All three extractors share `ArchivePaths.c`, so they refuse
  the same unsafe names in the same way.
- **libarchive:** the RAR 4 and RAR 5 readers of libarchive 3.8.9 (BSD-2-Clause, Tim Kientzle and
  contributors; the RAR 5 reader is Grzegorz Antoniak's clean-room decoder) and the core they sit
  on, 25 sources in `Sources/CArchives/libarchive`, plus `RarExtract.c`. Deliberately not RARLAB's
  `unrar`, whose licence is not an open-source one. `config.h` there is written by hand for Apple
  platforms and switches everything else off: no compression libraries, no iconv, no crypto (an
  encrypted archive is refused), no ACLs or extended attributes. `archive_blake2*` is CC0 and
  `archive_ppmd7.c` public domain; see `libarchive/COPYING`. To take a newer libarchive, replace
  the files with the same-named ones from its `libarchive/` folder and keep `config.h`.
- **XiphCodecs:** see `Vendor/README.md`.
