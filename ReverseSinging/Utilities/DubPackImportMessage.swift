//
//  DubPackImportMessage.swift
//  ReverseSinging
//
//  What the user is told when a dub pack will not import
//

import DubPackKit
import Foundation

/// The sentence shown for a failed import, in the user's language.
///
/// DubPackKit says what went wrong; the words are the app's.
nonisolated enum DubPackImportMessage {

    static func text(for error: Error) -> String {
        guard let error = error as? DubPackImportError else {
            return error.localizedDescription
        }

        switch error {
        case .sourceMissing:
            return Strings.Dub.Error.notAFolder
        case .unsupportedSource(let fileExtension) where fileExtension.isEmpty:
            return Strings.Dub.Error.notAFolder
        case .unsupportedSource(let fileExtension):
            return String(format: Strings.Dub.Error.unsupportedArchive, fileExtension)
        case .archiveUnreadable(let failure):
            return String(format: Strings.Dub.Error.unreadableArchive, text(for: failure))
        case .noPackFound:
            return Strings.Dub.Error.missingPackInfo
        case .noLines:
            return Strings.Dub.Error.noLines
        case .installFailed(let detail):
            // The file system's own message, already in the user's language.
            return detail
        case .cancelled:
            return CocoaError(.userCancelled).localizedDescription
        }
    }

    static func text(for failure: ArchiveFailure) -> String {
        switch failure {
        case .notAnArchive, .corrupt:
            return Strings.Dub.Error.archiveCorrupt
        case .unsupportedMethod:
            return Strings.Dub.Error.archiveUnsupported
        case .encrypted:
            return Strings.Dub.Error.archiveEncrypted
        case .tooLarge, .outOfMemory:
            return Strings.Dub.Error.archiveTooLarge
        case .io(let detail):
            return detail
        }
    }
}

nonisolated extension DubPackInstallProgress.Stage {
    /// What the progress overlay says during this stage.
    var message: String {
        switch self {
        case .copying: Strings.Dub.importing
        case .convertingVideo: Strings.Dub.convertingVideo
        case .reading: Strings.Dub.importReading
        }
    }
}
