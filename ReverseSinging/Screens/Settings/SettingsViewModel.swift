//
//  SettingsViewModel.swift
//  ReverseSinging
//
//  What the settings screen reads and changes: preferences, the camera, the purchase
//

import SwiftUI
import Combine
import RevenueCat

/// Which settings a presentation is allowed to show.
///
/// The menu owns nothing but the app itself, so opening settings from there must
/// not offer choices that belong to one game. The Simple/Complex interface is a
/// property of reverse singing, and is meaningless before a game is picked.
enum SettingsScope {
    case app
    case reverseSinging
}

/// Drives the settings screen.
///
/// The interface and feedback preferences belong to `AppViewModel` and the purchase to
/// `AccessController`; changes to either are passed on as this model's own, so the screen
/// only has to watch this one.
@MainActor
final class SettingsViewModel: ObservableObject {

    /// Defaults to the narrow set; a game screen opts in to its own options.
    let scope: SettingsScope

    @Published private(set) var soundsEnabled: Bool

    @Published var isPaywallPresented = false
    @Published var isCustomerCenterPresented = false

    @Published var isConfirmingBoothDelete = false
    @Published private(set) var boothUsage: (bytes: Int64, packs: Int) = (0, 0)
    @Published private(set) var isBoothDenied: Bool

    private let app: AppViewModel
    private let access: AccessController
    private var cancellables = Set<AnyCancellable>()

    init(app: AppViewModel, scope: SettingsScope) {
        self.app = app
        self.scope = scope
        access = AccessController.shared
        soundsEnabled = SoundManager.shared.isEnabled
        isBoothDenied = BoothRecorder.cameraPermission == .refused

        app.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        access.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: - Screen

    func onAppear() {
        AnalyticsManager.shared.trackSettingsOpened()
        AnalyticsManager.shared.trackScreenViewed(screenName: "SettingsView")
    }

    /// The interface choice belongs to reverse singing, so it only appears when settings are
    /// opened from that game.
    var showsInterfaceSection: Bool { scope == .reverseSinging }

    // MARK: - Preferences

    var uiMode: UIMode { app.uiMode }

    var hapticsEnabled: Bool { app.hapticsEnabled }

    func setUIMode(_ mode: UIMode) {
        app.setUIMode(mode)
    }

    func setHapticsEnabled(_ enabled: Bool) {
        app.setHapticsEnabled(enabled)
        if enabled {
            HapticManager.shared.medium()
        }
    }

    /// Interface sound effects, the clapper, the transport clicks, the render chime.
    func setSoundsEnabled(_ enabled: Bool) {
        app.setSoundsEnabled(enabled)
        soundsEnabled = enabled
    }

    // MARK: - Booth Cam

    /// Flipping this on is also where the camera gets asked for, if it never has been.
    ///
    /// The full explanation lives on the record screen, where the feature is about to be
    /// used. Here the row itself is the explanation, so this goes straight to the system.
    func setBoothEnabled(_ enabled: Bool) {
        let booth = BoothCamPreference.shared

        guard enabled else {
            booth.isEnabled = false
            return
        }

        switch BoothRecorder.cameraPermission {
        case .granted:
            booth.isEnabled = true
            BoothCamPreference.shared.markPrimerSeen()
        case .unasked:
            Task {
                let granted = await BoothRecorder.requestAccess()
                BoothCamPreference.shared.markPrimerSeen()
                booth.isEnabled = granted
                isBoothDenied = !granted
            }
        case .refused:
            isBoothDenied = true
            booth.isEnabled = false
        }
    }

    func refreshBoothUsage() {
        isBoothDenied = BoothRecorder.cameraPermission == .refused

        Task {
            boothUsage = await Task.detached(priority: .utility) {
                AudioFileManager.shared.boothFootageUsage()
            }.value
        }
    }

    func deleteBoothFootage() {
        HapticManager.shared.medium()
        Task {
            boothUsage = await Task.detached(priority: .userInitiated) {
                try? AudioFileManager.shared.deleteAllBoothFootage()
                return AudioFileManager.shared.boothFootageUsage()
            }.value
        }
        AnalyticsManager.shared.trackCustomEvent(name: "booth_footage_deleted", parameters: nil)
    }

    // MARK: - Purchase

    var isEarlyAdopter: Bool { access.isEarlyAdopter }

    var isPro: Bool { access.isPro }

    var isRestoring: Bool { access.isRestoring }

    /// The trial counter, restated as a sentence, or the plain offer once it is over.
    var unlockSubtitle: String {
        guard let days = access.trialDaysRemaining else { return Strings.Pro.unlockSubtitle }
        return days <= 1
            ? Strings.Pro.Trial.oneDayLeft
            : String(format: Strings.Pro.Trial.daysLeft, days)
    }

    func showPaywall() {
        isPaywallPresented = true
    }

    func openCustomerCenter() {
        AnalyticsManager.shared.trackCustomerCenterOpened()
        isCustomerCenterPresented = true
    }

    /// A restore that happened inside RevenueCat's Customer Center.
    func customerCenterDidRestore(_ customerInfo: CustomerInfo) {
        access.handleCompletion(customerInfo)
    }

    func restore() {
        Task { await access.restore() }
    }

    // MARK: - About

    var versionText: String? {
        guard let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
              let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String else { return nil }
        return String(format: Strings.Settings.version, version, build)
    }

    func openPrivacyPolicy() {
        HapticManager.shared.light()
        AnalyticsManager.shared.trackCustomEvent(name: "privacy_policy_opened", parameters: nil)

        if let url = URL(string: "https://falsepeak.ch/privacy") {
            UIApplication.shared.open(url)
        }
    }
}
