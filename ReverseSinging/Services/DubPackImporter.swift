//
//  DubPackImporter.swift
//  ReverseSinging
//
//  Brings a dub pack into the app's own storage
//

import DubPackKit
import Foundation

/// Imports a dub pack: a folder, a `.zip` or a `.7z`.
///
/// DubPackKit does the installing and the reading, and reports to Crashlytics everything it
/// had to drop or could not open. This adds what only the app knows about: the pack's identity,
/// its speech windows, and the manifest that caches both.
nonisolated struct DubPackImporter {

    static let shared = DubPackImporter()

    typealias ProgressHandler = @Sendable (DubPackInstallProgress) -> Void

    private let installer: DubPackInstaller

    init(installer: DubPackInstaller = DubPackInstaller(
        libraryDirectory: AudioFileManager.shared.dubPacksDirectory(),
        ignoredFileNames: [DubPackManifest.filename],
        reporter: CrashlyticsDubPackReporter()
    )) {
        self.installer = installer
    }

    /// Imports the pack at `source`, which may be security scoped.
    ///
    /// - Throws: `DubPackImportError`. `DubPackImportMessage` turns it into a sentence.
    @concurrent
    func importPack(from source: URL, progress: ProgressHandler? = nil) async throws -> DubPack {
        let didScope = source.startAccessingSecurityScopedResource()
        defer { if didScope { source.stopAccessingSecurityScopedResource() } }

        // A pack that replaces one installed under the same name keeps that pack's identity.
        // Takes are stored under the id, so a re-import (a rebuilt starter pack, or the same
        // zip brought in again) would otherwise orphan every line recorded against it.
        let previous = DubPackManifest.read(at: installer.installLocation(for: source))

        let installed = try await installer.install(from: source, progress: progress)
        let pack = DubPack(parsed: installed.pack, directory: installed.directory, id: previous?.id ?? UUID())

        do {
            try DubPackManifest.write(pack, to: installed.directory)
        } catch {
            // The pack is installed and plays; without a manifest the library reads it again
            // on the next launch, which is slower but correct.
            CrashReporter.shared.record(error, context: "dub_pack.manifest_write", keys: ["pack_title": pack.title])
        }

        return pack
    }
}
