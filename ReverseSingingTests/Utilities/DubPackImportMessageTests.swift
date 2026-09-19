//
//  DubPackImportMessageTests.swift
//  ReverseSingingTests
//
//  What the user reads when a pack will not import
//

import DubPackKit
import Foundation
import Testing
@testable import ReverseSinging

@Suite("Dub Pack Import Messages")
struct DubPackImportMessageTests {

    @Test func asksForAPackWhenThereIsNothingToOpen() {
        #expect(DubPackImportMessage.text(for: DubPackImportError.sourceMissing) == Strings.Dub.Error.notAFolder)
        #expect(DubPackImportMessage.text(for: DubPackImportError.unsupportedSource(fileExtension: "")) == Strings.Dub.Error.notAFolder)
    }

    @Test func namesTheArchiveFormatItCannotOpen() {
        #expect(
            DubPackImportMessage.text(for: DubPackImportError.unsupportedSource(fileExtension: "rar"))
                == String(format: Strings.Dub.Error.unsupportedArchive, "rar")
        )
    }

    @Test(arguments: [
        (ArchiveFailure.notAnArchive, Strings.Dub.Error.archiveCorrupt),
        (.corrupt(detail: "crc mismatch"), Strings.Dub.Error.archiveCorrupt),
        (.unsupportedMethod(detail: "method 0x30401"), Strings.Dub.Error.archiveUnsupported),
        (.encrypted, Strings.Dub.Error.archiveEncrypted),
        (.tooLarge(detail: "900 MB block"), Strings.Dub.Error.archiveTooLarge),
        (.outOfMemory, Strings.Dub.Error.archiveTooLarge),
        (.io(detail: "No space left on device"), "No space left on device"),
    ])
    func explainsWhyAnArchiveWouldNotOpen(failure: ArchiveFailure, reason: String) {
        #expect(
            DubPackImportMessage.text(for: DubPackImportError.archiveUnreadable(failure))
                == String(format: Strings.Dub.Error.unreadableArchive, reason)
        )
    }

    @Test func explainsAPackThatCameInEmpty() {
        #expect(DubPackImportMessage.text(for: DubPackImportError.noPackFound) == Strings.Dub.Error.missingPackInfo)
        #expect(DubPackImportMessage.text(for: DubPackImportError.noLines(issues: [])) == Strings.Dub.Error.noLines)
    }

    @Test func passesTheSystemsOwnMessageThrough() {
        #expect(DubPackImportMessage.text(for: DubPackImportError.installFailed(detail: "The disk is full.")) == "The disk is full.")
    }

    @Test func fallsBackToAnErrorsOwnDescription() {
        let error = CocoaError(.fileWriteOutOfSpace)

        #expect(DubPackImportMessage.text(for: error) == error.localizedDescription)
    }

    @Test func everyInstallStageHasSomethingToSay() {
        for stage in DubPackInstallProgress.Stage.allCases {
            #expect(!stage.message.isEmpty)
        }
    }
}
