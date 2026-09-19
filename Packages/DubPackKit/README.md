# DubPackKit

Imports community dub packs ("mods") for Dubloon: from a folder, a `.zip` or a `.7z`, in the
shapes packs actually arrive in rather than only the one the format describes, and from zips that
did not finish downloading. It knows nothing
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

let installed = try await installer.install(from: pickedURL) { progress in
    // progress.stage: .copying, .convertingVideo, .reading; progress.fraction: 0...1
}
installed.pack      // ParsedPack: title, authors, icon, backing track, video, lines, provenance
installed.issues    // [DubPackIssue]: everything that was dropped or worked around
```

`DubPackReader` reads a pack that is already installed. It never reports, so re-reading a pack
on a later launch cannot repeat the non-fatals its import sent.

A failed install throws `DubPackImportError`. It carries no user-facing text: switch over it and
say it in the user's language. A failed re-install leaves the pack already installed under the
same name untouched.

## What a pack may look like

The format as specified is `_pack_info.ini`, then `NNN_Character.txt` + `.jpg` + `.wav` per line,
`_backing_track.mp3` and `dub_video.ogv`, all flat in one folder. All of these variations read too:

| Part | Accepted |
|---|---|
| Where the pack is | Files at the top of the archive, or up to three folders down. `__MACOSX` is ignored. A folder can also be reached through a symbolic link. |
| Archive | `.zip`, and `.7z` compressed with LZMA, LZMA2, PPMd, Deflate, BZip2 or stored. Recognised by their bytes, so a renamed file still opens. |
| Damaged zip | A zip whose index is missing or refused, typically a cut-off download, is read entry by entry from the front. Entries failing their checksum are left out; a file cut off by the end is kept only if it is audio. |
| Pack info | `_pack_info.ini`, `pack_info.ini`, `_packinfo.ini`, `packinfo.ini`, `_pack_info.txt`, `pack_info.txt`, in any case. Optional: without one, the pack is titled after the folder it came wrapped in, else after the archive or folder name. |
| Line entries | `NN_Character.txt` or `NN_Character.ini`; the `.txt` wins when both exist. Unnumbered text files count only when they carry line keys. |
| Text encoding | UTF-8 with or without a byte-order mark, UTF-16, Windows-1252. CRLF or LF. |
| Keys | Any case. `key=value` or `key = value`. Quoted, single-quoted or bare values. `#` and `;` comments. |
| Line audio | `.wav`, `.mp3`, `.m4a`, `.aac`, `.aif`, `.caf`, `.flac` and more, beside the entry or named by an `audio` key. The first that decodes wins. |
| Stills | `.jpg`, `.png`, `.heic`, `.webp` and more, named by `image` or beside the entry. A missing still borrows the previous line's. |
| Timestamps | `6.716`, `6,716`, `6.716s`, `1:06.716`. Under `dub_timestamps`, `timestamp`, `start` and similar. |
| Character | `dub_characters`, `character`, `speaker`, else taken from the file name (`018_Mr_Dursley` is "Mr Dursley"). |
| Backing track | `_backing_track`, `backing_track`, `backing`, `instrumental` with any audio extension, else the only audio file no line uses. |
| Scene video | `dub_video`, `video`, `scene` with any video extension, else the only unnumbered video. Theora is converted to H.264. |
| Icon | Named by `icon`, else `icon.*` or `cover.*`, else the first line's still. |

What still drops a line: no start time, an unreadable start time, or no audio that decodes.

## What gets reported

The installer sends one `DubPackIssueReport` per kind of issue per pack, after the pack is read.
If the install fails, it sends the issues found so far and then one report for the failure. The
`context` and `kind.code` are stable, so a crash reporter can group on them. Keys hold file names
from inside the pack, counts and the pack's own title, never what a line says.

| Context | When | Keys besides `pack_title` |
|---|---|---|
| `dub_pack.dropped_lines` | Entries that could not become lines | `dropped_count`, `candidate_count`, `kept_count`, `reasons`, `sample` |
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
| `dub_pack.video_transcode` | Theora conversion failed or came out the wrong length | `source_extension`, `failure`, `expected_seconds`, `actual_seconds`, `detail` |
| `dub_pack.recovered_archive` | A zip was cut off, or had entries failing their checksum | `truncated_entry`, `partial_kept`, `damaged_count` |
| `dub_pack.skipped_archive_entries` | Archive entries pointing outside the pack | `skipped_count` |
| `dub_pack.import` | The install failed | `failure`, `stage`, `source_extension`, `detail` |

Breadcrumbs go to `DubPackIssueReporter.log`: `dub_pack.import began (.7z)`, then `staged`,
`installed`, `converted`, `read`, or `failed <code>`.

## Layout

```
Sources/DubPackKit/
  Import/     DubPackInstaller and the steps of an install: staging, finding the pack, installing
  Archives/   Recognising and unpacking .zip and .7z, and recovering damaged zips
  Reading/    DubPackReader and the format: fields, text encodings, timestamps, file lookup
  Video/      Theora to H.264
  Media/      The AVFoundation probe for what decodes
  Issues/     DubPackIssue, grouping into reports, the reporter protocol
Sources/CArchives/   In C: the LZMA SDK's 7z decoder with a streaming extractor, and the zip recovery
Vendor/              XiphTheora.xcframework (libogg + libtheora decoder) and its build script
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
  for archives whose index is gone. Both share `ArchivePaths.c`, so they refuse the same unsafe
  names in the same way.
- **XiphTheora:** see `Vendor/README.md`.
