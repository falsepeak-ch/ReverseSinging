//
//  PackFormat.swift
//  DubPackKit
//

/// The names and keys of the community dub-pack format, with every variation real packs have
/// been seen to use.
///
/// The format describes one shape: `_pack_info.ini`, then `NNN_Character.txt` + `.jpg` + `.wav`
/// per line, `_backing_track.mp3` and `dub_video.ogv`. Packs arrive in a dozen others. Lists
/// are in order of preference, canonical name first, and every comparison ignores case.
enum PackFormat {

    enum Files {
        static let packInfo = [
            "_pack_info.ini", "pack_info.ini", "_packinfo.ini", "packinfo.ini",
            "_pack_info.txt", "pack_info.txt",
        ]

        static let backingTrackStems = [
            "_backing_track", "backing_track", "_backingtrack", "backingtrack",
            "_backing", "backing", "_instrumental", "instrumental",
        ]

        static let sceneVideoStems = [
            "dub_video", "_dub_video", "dubvideo", "video", "_video", "scene", "_scene",
        ]

        static let iconStems = ["icon", "cover"]

        /// Extensions a line entry is written with. The format says `.txt`; some pack tools
        /// write `.ini`, the same `[data]` text under another name.
        static let entryExtensions: Set<String> = ["txt", "ini"]

        /// The tail of this list is formats AVFoundation may not decode. They are still
        /// looked for, so that a line recorded as Ogg is reported as unplayable rather than
        /// missing, which points its author at the real problem.
        static let audioExtensions = [
            "wav", "mp3", "m4a", "aac", "aif", "aiff", "caf", "flac", "ogg", "oga", "opus", "wma",
        ]

        static let imageExtensions = [
            "jpg", "jpeg", "png", "webp", "heic", "heif", "gif", "bmp", "tif", "tiff",
        ]

        static let videoExtensions = ["mp4", "mov", "m4v", "ogv", "ogg", "webm", "mkv", "avi"]

        /// Containers that hold Theora, which is converted to H.264 at install.
        static let theoraExtensions: Set<String> = ["ogv", "ogg"]

        /// What operating systems leave in archives and folders. Never installed.
        static let clutter: Set<String> = ["__macosx", "thumbs.db", "desktop.ini"]
    }

    enum Keys {
        // Pack info
        static let title = ["title", "name"]
        static let authors = ["authors", "author"]
        static let icon = ["icon", "image", "cover"]
        static let source = ["source"]
        static let sourceURL = ["source_url"]
        static let rights = ["rights", "license", "licence"]

        // Line entries
        static let caption = ["caption", "text", "line", "dialogue", "subtitle"]
        static let image = ["image", "still", "picture"]
        static let timestamps = [
            "dub_timestamps", "dub_timestamp", "timestamps", "timestamp", "start_time", "start", "time",
        ]
        static let characters = [
            "dub_characters", "dub_character", "characters", "character", "speaker", "name",
        ]
        static let audio = ["audio", "sound", "dub_audio", "wav"]

        /// A text file carrying any of these is a line entry, even without a number in its name.
        static let entryMarkers = Set(caption + image + timestamps + characters + audio)
    }
}
