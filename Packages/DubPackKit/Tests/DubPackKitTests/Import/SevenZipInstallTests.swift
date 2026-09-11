//
//  SevenZipInstallTests.swift
//  DubPackKitTests
//

import Foundation
import Testing
@testable import DubPackKit

@Suite("Installer: 7z")
struct SevenZipInstallTests {

    private func copy(_ fixture: String, as name: String, in temp: TemporaryDirectory) throws -> URL {
        let url = temp.appending(name)
        try FileManager.default.copyItem(at: Fixtures.url(fixture), to: url)
        return url
    }

    @Test func installsASevenZipWithAWrappingFolder() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let archive = try copy("pack_lzma2.7z", as: "Fixture Pack.7z", in: temp)

        let installed = try await DubPackInstaller.testing(library: temp.appending("library")).install(from: archive)

        #expect(installed.folderName == "Fixture Pack")
        #expect(installed.pack.title == "Fixture Pack")
        #expect(installed.pack.lines.map(\.referenceAudioFile) == ["001_Hero.wav", "002_Hero.mp3"])
        #expect(installed.pack.lines[1].imageFile == "002_Hero.png")
        #expect(installed.pack.backingTrackFile == "_backing_track.mp3")
        #expect(installed.issues.isEmpty)
    }

    @Test(arguments: ["lzma1", "ppmd", "deflate", "bzip2", "store"])
    func installsEveryCompressionMethod(method: String) async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let archive = try copy("pack_\(method).7z", as: "\(method).7z", in: temp)

        let installed = try await DubPackInstaller.testing(library: temp.appending("library")).install(from: archive)

        #expect(installed.pack.lines.count == 2)
        #expect(abs(installed.pack.duration - 2) < 0.2)
    }

    /// `release/Fixture Pack/…`: an archive of a folder of packs.
    @Test func findsThePackTwoFoldersDown() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let archive = try copy("pack_nested.7z", as: "nested.7z", in: temp)

        let installed = try await DubPackInstaller.testing(library: temp.appending("library")).install(from: archive)

        #expect(installed.pack.title == "Fixture Pack")
        #expect(installed.folderName == "nested")
    }

    @Test func installsASevenZipWithFilesAtTheRoot() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let archive = try copy("pack_flat.7z", as: "flat-pack.7z", in: temp)

        let installed = try await DubPackInstaller.testing(library: temp.appending("library")).install(from: archive)

        #expect(installed.folderName == "flat-pack")
        #expect(installed.pack.lines.count == 2)
    }

    /// Chat apps rename attachments; the bytes decide.
    @Test func installsASevenZipRenamedToZip() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let archive = try copy("pack_lzma2.7z", as: "renamed.zip", in: temp)

        let installed = try await DubPackInstaller.testing(library: temp.appending("library")).install(from: archive)

        #expect(installed.pack.lines.count == 2)
    }

    @Test func notesEntriesThatTriedToLeaveThePack() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let archive = try copy("pack_unsafe_path.7z", as: "unsafe.7z", in: temp)

        let installed = try await DubPackInstaller.testing(library: temp.appending("library")).install(from: archive)

        #expect(installed.pack.lines.count == 2)
        #expect(installed.issues == [.unsafeArchiveEntriesSkipped(count: 1)])
    }

    @Test func refusesADamagedArchiveAsCorrupt() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let whole = try Data(contentsOf: Fixtures.url("pack_lzma2.7z"))
        let cut = temp.appending("cut.7z")
        try whole.prefix(whole.count / 2).write(to: cut)

        await #expect {
            try await DubPackInstaller.testing(library: temp.appending("library")).install(from: cut)
        } throws: { error in
            guard case .archiveUnreadable(.corrupt) = error as? DubPackImportError else { return false }
            return true
        }
    }
}
