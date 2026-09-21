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
        #expect(DubPackImportMessage.text(for: DubPackImportError.noPackFound()) == Strings.Dub.Error.emptySource)
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

    /// A font pack, as one user picked: the message names what was in it.
    @Test func somethingThatIsNotAPackIsDescribedByWhatItHolds() {
        let font = DubPackImportError.noPackFound(fileTypes: ["bfotf": 2, "webp": 1])
        #expect(DubPackImportMessage.text(for: font) == String(format: Strings.Dub.Error.notADubPack, ".bfotf, .webp"))

        let mod = DubPackImportError.noPackFound(fileTypes: ["class": 189, "json": 59, "png": 3, "toml": 1])
        #expect(DubPackImportMessage.text(for: mod) == String(format: Strings.Dub.Error.notADubPack, ".class, .json, .png, …"))
    }

    /// A pack whose every line was dropped says why, by the reason most of its lines share.
    @Test func aPackWithNoUsableLinesSaysWhy() {
        func dropped(_ reasons: [DroppedLineReason]) -> DubPackImportError {
            .noLines(issues: reasons.enumerated().map { .droppedLine(file: "\($0.offset).txt", reason: $0.element) })
        }

        #expect(DubPackImportMessage.text(for: dropped([.missingTimestamp, .missingTimestamp, .missingAudio])) == Strings.Dub.Error.linesNoTimestamps)
        #expect(DubPackImportMessage.text(for: dropped([.invalidTimestamp])) == Strings.Dub.Error.linesBadTimestamps)
        #expect(DubPackImportMessage.text(for: dropped([.missingAudio])) == Strings.Dub.Error.linesNoAudio)
        #expect(DubPackImportMessage.text(for: dropped([.unplayableAudio])) == Strings.Dub.Error.linesUnplayableAudio)
        #expect(DubPackImportMessage.text(for: dropped([.unreadableText])) == Strings.Dub.Error.noLines)
    }
}
