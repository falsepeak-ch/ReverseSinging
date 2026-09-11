//
//  DubLibraryViewModel.swift
//  ReverseSinging
//
//  The dub library: importing packs, opening and deleting them, and the mode's own options
//

import SwiftUI
import Combine

/// Drives the library of dub packs installed on this device.
///
/// Owns the `DubPackLibrary` for as long as the screen is up, and passes its changes on as
/// this model's own: the packs, the import progress and its errors are most of what the screen
/// draws.
@MainActor
final class DubLibraryViewModel: ObservableObject {

    let library: DubPackLibrary

    @Published var showFileImporter = false
    @Published var showContentGate = false
    @Published var selectedPack: DubPack?

    private var cancellables = Set<AnyCancellable>()

    init() {
        library = DubPackLibrary()

        library.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: - Screen

    func onAppear() {
        library.reload()
        AnalyticsManager.shared.trackScreenViewed(screenName: "DubLibrary")
    }

    // MARK: - Packs

    func open(_ pack: DubPack) {
        selectedPack = pack
    }

    func delete(_ pack: DubPack) {
        library.delete(pack)
    }

    func recordedCount(for pack: DubPack) -> Int {
        library.recordedCount(for: pack)
    }

    // MARK: - Import

    /// Asked every time. The gate is not a consent checkbox to be got past once,
    /// it is where the app says it hosts nothing, where the rights disclaimer
    /// lives, and the only route to "where do these files come from". Remembering
    /// a yes hid all three from everyone who had already answered.
    func requestImport() {
        showContentGate = true
    }

    /// Beyond the starter scenes the app hosts nothing, so the picker only opens once the
    /// gate has had its say.
    func contentGateDidConfirm() {
        showFileImporter = true
    }

    func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task { await library.importPack(from: url) }
        case .failure(let error):
            library.errorMessage = error.localizedDescription
            // The picker itself failed, so no import ever started and neither the import
            // events nor `DubPackLibrary`'s non-fatal will ever mention it. From the user's
            // side this is indistinguishable from a pack that would not open.
            CrashReporter.shared.record(error, context: "dub_pack.file_picker")
        }
    }

    /// A pack handed to the app from outside, AirDrop or "Open with".
    func importPack(from url: URL) async {
        await library.importPack(from: url)
    }

    // MARK: - Options

    /// The booth switch is offered only once the camera has been granted: the explanation the
    /// first "yes" deserves does not fit in a menu row.
    var canToggleBooth: Bool {
        BoothRecorder.cameraPermission == .granted
    }

    func scoringDidChange(enabled: Bool) {
        HapticManager.shared.light()
        AnalyticsManager.shared.trackDubScoringToggled(enabled: enabled)
    }

    func boothDidChange(enabled: Bool) {
        HapticManager.shared.light()
        AnalyticsManager.shared.trackCustomEvent(
            name: enabled ? "booth_cam_enabled" : "booth_cam_disabled",
            parameters: nil
        )
    }

    // MARK: - Screenshots

    #if DEBUG
    /// The pack itself is copied into Documents/DubPacks by capture.sh; the takes
    /// have to be written here, because they are keyed by the id the parser hands
    /// the pack on this launch.
    ///
    /// Waiting on the reload `DubPackLibrary.init` already started, rather than
    /// calling `reloadNow()` again: an unimported pack has no manifest yet, so two
    /// concurrent loads each parse it and each mint a different pack id. Takes
    /// seeded against one id are invisible to the other, which is exactly how the
    /// record screen came out reading 0 dubbed with seven takes on disk.
    func seedScreenshotTakes() async {
        guard ScreenshotMode.isActive else { return }

        var waited = 0
        while library.packs.isEmpty && waited < 120 {
            try? await Task.sleep(for: .milliseconds(80))
            waited += 1
        }
        guard let pack = library.packs.first else { return }

        ScreenshotMode.seedTakes(for: pack)
        await library.reloadNow()

        if ScreenshotMode.destination?.opensPack == true {
            // The app preview opens here, so the library needs a beat on screen
            // before the push. A still frame doesn't.
            if ScreenshotMode.destination?.isTour == true {
                try? await Task.sleep(for: .seconds(ScreenshotMode.Tour.libraryHold))
            }
            selectedPack = library.packs.first { $0.id == pack.id } ?? pack
        }
    }
    #endif
}
