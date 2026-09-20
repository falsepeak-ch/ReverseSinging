//
//  DubPackInstaller.swift
//  DubPackKit
//

public import Foundation

/// Brings a dub pack into a library folder: from a folder, a `.zip` or a `.7z`.
///
/// One install stages the source (unpacking an archive, which is recognised by its bytes rather
/// than its name, and recovering a zip that was cut off, and waiting for iCloud when the file is
/// not here yet), finds the pack inside it however deeply it is wrapped, assembles it out of
/// sight in the library, converts Vorbis audio to AAC and a Theora scene to H.264, reads it, and
/// only then puts it in place of any installed pack with the same name.
///
/// Everything the install had to drop or work around is returned in `InstalledDubPack.issues`
/// and, when a reporter is given, sent to it once at the end, grouped by kind. A failure sends
/// the issues found so far and then one report for the failure itself.
public struct DubPackInstaller: Sendable {

    /// Where installed packs live, one folder each.
    public let libraryDirectory: URL

    private let installation: PackInstallation
    private let reporter: (any DubPackIssueReporter)?
    private let probe: any MediaProbe
    private let temporaryDirectory: URL

    /// - Parameters:
    ///   - libraryDirectory: where installed packs live. Created when missing.
    ///   - ignoredFileNames: names never copied from a source, such as the host's cache file,
    ///     which describes an install and must not arrive inside somebody's archive.
    ///   - reporter: receives breadcrumbs and one report per kind of issue.
    public init(
        libraryDirectory: URL,
        ignoredFileNames: Set<String> = [],
        reporter: (any DubPackIssueReporter)? = nil
    ) {
        self.init(
            libraryDirectory: libraryDirectory,
            ignoredFileNames: ignoredFileNames,
            reporter: reporter,
            probe: AVFoundationMediaProbe(),
            temporaryDirectory: FileManager.default.temporaryDirectory
        )
    }

    init(
        libraryDirectory: URL,
        ignoredFileNames: Set<String>,
        reporter: (any DubPackIssueReporter)?,
        probe: any MediaProbe,
        temporaryDirectory: URL
    ) {
        self.libraryDirectory = libraryDirectory
        self.installation = PackInstallation(libraryDirectory: libraryDirectory, ignoredFileNames: ignoredFileNames)
        self.reporter = reporter
        self.probe = probe
        self.temporaryDirectory = temporaryDirectory
    }

    /// The folder `source` installs into. Read what is there before installing to carry
    /// anything of the previous install forward, such as its identity.
    public func installLocation(for source: URL) -> URL {
        installation.destination(forFolderName: PackInstallation.folderName(for: source))
    }

    /// A step the host runs on the assembled pack before it replaces the installed one: the
    /// place to write anything of the host's own into the folder, such as a cache file. Gets
    /// the folder as it is now (hidden, inside the library), where it is about to be, and what
    /// was read from it. A throw fails the install and leaves the previous one untouched.
    public typealias BeforeCommit = @Sendable (_ incoming: URL, _ destination: URL, _ pack: ParsedPack) throws -> Void

    /// Installs the pack at `source`.
    ///
    /// `source` may be security scoped; the caller is responsible for accessing it.
    @concurrent
    public func install(
        from source: URL,
        progress: (@Sendable (DubPackInstallProgress) -> Void)? = nil,
        beforeCommit: BeforeCommit? = nil
    ) async throws(DubPackImportError) -> InstalledDubPack {
        let sourceExtension = source.pathExtension.lowercased()
        let folderName = PackInstallation.folderName(for: source)

        var stage = DubPackInstallProgress.Stage.copying
        var issues: [DubPackIssue] = []
        var incoming: URL?

        reporter?.log("dub_pack.import began (.\(sourceExtension))")

        do throws(DubPackImportError) {
            progress?(.init(stage: .copying, fraction: 0))
            try installation.prepareLibrary()

            let staged = try StagedSource.stage(source, temporaryRoot: temporaryDirectory) { fraction in
                progress?(.init(stage: .copying, fraction: fraction * 0.8))
            }
            defer { staged.discard() }
            reporter?.log("dub_pack.import staged")

            if let recovery = staged.recovery, recovery.isDegraded {
                issues.append(.archiveRecovered(
                    truncatedEntry: recovery.truncatedEntry.map { ($0 as NSString).lastPathComponent },
                    partialKept: recovery.partialKept,
                    damagedEntries: recovery.damagedEntries
                ))
            }
            if staged.skippedEntries > 0 {
                issues.append(.unsafeArchiveEntriesSkipped(count: staged.skippedEntries))
            }

            try checkCancellation()
            guard let root = PackRootFinder.root(in: staged.directory) else {
                let fileTypes = PackRootFinder.fileTypeCounts(in: staged.directory)
                issues.append(.noLineEntries(fileTypes: fileTypes))
                throw .noPackFound(fileTypes: fileTypes)
            }

            // Without pack info, a pack is titled after the folder it came wrapped in, which was named
            // for people, rather than after an archive name such as `forrest_gump_-_proposal.zip`.
            let isWrapped = root.standardizedFileURL.path != staged.directory.standardizedFileURL.path
            let fallbackTitle = isWrapped ? root.lastPathComponent : folderName

            let assembled = try installation.assemble(from: root, moving: staged.isTemporary)
            incoming = assembled
            reporter?.log("dub_pack.import installed")
            progress?(.init(stage: .copying, fraction: 1))

            stage = .convertingAudio
            try checkCancellation()
            progress?(.init(stage: .convertingAudio, fraction: 0))
            let audio = AudioTrackConverter.convertIfNeeded(in: assembled) { fraction in
                progress?(.init(stage: .convertingAudio, fraction: fraction))
            }
            issues += audio.issues
            if !audio.converted.isEmpty {
                reporter?.log("dub_pack.import converted \(audio.converted.count) vorbis files")
            }

            stage = .convertingVideo
            try checkCancellation()
            let conversion = await SceneVideoConverter.convertIfNeeded(in: assembled, probe: probe) { fraction in
                progress?(.init(stage: .convertingVideo, fraction: fraction))
            }
            switch conversion {
            case .nothingToConvert, .converted:
                break
            case .failed(let file, let failure):
                issues.append(.videoConversionFailed(file: file, failure: failure))
            case .deferred(let file, let failure):
                issues.append(.videoConversionDeferred(file: file, failure: failure))
            }
            reporter?.log("dub_pack.import converted")

            stage = .reading
            try checkCancellation()
            progress?(.init(stage: .reading, fraction: 0))
            let reading = try await DubPackReader(probe: probe).read(at: assembled, fallbackTitle: fallbackTitle)
            issues += reading.issues

            if let beforeCommit {
                do {
                    try beforeCommit(assembled, installation.destination(forFolderName: folderName), reading.pack)
                } catch {
                    throw DubPackImportError.installFailed(detail: error.localizedDescription)
                }
            }

            let directory = try installation.commit(assembled, as: folderName)
            incoming = nil
            reporter?.log("dub_pack.import read")
            progress?(.init(stage: .reading, fraction: 1))

            record(
                issues,
                packTitle: reading.pack.title,
                candidateLineCount: reading.candidateLineCount,
                keptLineCount: reading.pack.lines.count
            )

            return InstalledDubPack(folderName: folderName, directory: directory, pack: reading.pack, issues: issues)
        } catch {
            if let incoming { installation.discard(incoming) }

            if case .noLines(let readerIssues) = error {
                issues += readerIssues
            }
            let dropped = issues.filter { if case .droppedLine = $0 { true } else { false } }.count
            record(issues, packTitle: folderName, candidateLineCount: dropped, keptLineCount: 0)

            // A cancelled import is somebody changing their mind, not a pack that failed.
            if error != .cancelled {
                reporter?.record(.importFailure(
                    error,
                    stage: stage,
                    sourceExtension: sourceExtension,
                    packTitle: folderName
                ))
            }
            reporter?.log("dub_pack.import failed \(error.telemetryCode)")
            throw error
        }
    }

    // MARK: - Helpers

    private func record(_ issues: [DubPackIssue], packTitle: String, candidateLineCount: Int, keptLineCount: Int) {
        guard let reporter else { return }
        let reports = DubPackIssueReport.reports(
            for: issues,
            packTitle: packTitle,
            candidateLineCount: candidateLineCount,
            keptLineCount: keptLineCount
        )
        reports.forEach(reporter.record)
    }

    private func checkCancellation() throws(DubPackImportError) {
        if Task.isCancelled { throw .cancelled }
    }
}

/// A pack that installed, with everything it lost on the way in.
public struct InstalledDubPack: Sendable, Hashable {
    /// The folder's name inside the library.
    public let folderName: String
    public let directory: URL
    public let pack: ParsedPack
    /// Empty when the pack came in whole.
    public let issues: [DubPackIssue]
}
