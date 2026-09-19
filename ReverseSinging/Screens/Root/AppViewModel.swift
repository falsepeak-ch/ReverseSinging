//
//  AppViewModel.swift
//  ReverseSinging
//
//  What the app keeps above any one game: onboarding, preferences, and what the menu presents
//

import SwiftUI
import Combine

/// The state that outlives any one game, owned by `ContentView`.
///
/// Onboarding, the interface and feedback preferences, and the hand-off of a pack opened from
/// outside belong to the app rather than to reverse singing, so they live here and
/// `ReverseGameViewModel` keeps only the game.
///
/// The `UserDefaults` keys are the ones installs already have. `EarlyAdopter` and
/// `BoothCamAnnouncement` read `hasCompletedOnboarding` and `uiMode` as evidence of earlier
/// use, so none of them may be renamed.
@MainActor
final class AppViewModel: ObservableObject {

    @Published private(set) var hasCompletedOnboarding: Bool
    @Published private(set) var uiMode: UIMode
    @Published private(set) var hapticsEnabled: Bool
    @Published private(set) var hasRecordingPermission = false

    /// The menu's settings sheet. A game presents its own.
    @Published var showSettings = false
    @Published var showDubLibrary = false

    /// Set when the system hands us a pack from AirDrop or "Open with"; the dub library
    /// picks it up and imports it.
    @Published var pendingDubImportURL: URL?

    private enum Key {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let uiMode = "uiMode"
        static let hapticsEnabled = "hapticsEnabled"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hasCompletedOnboarding = defaults.bool(forKey: Key.hasCompletedOnboarding)
        // Simple until someone picks a skin, haptics on until someone turns them off.
        uiMode = defaults.string(forKey: Key.uiMode).flatMap(UIMode.init(rawValue:)) ?? .simple
        hapticsEnabled = defaults.object(forKey: Key.hapticsEnabled) != nil
            ? defaults.bool(forKey: Key.hapticsEnabled)
            : true
    }

    // MARK: - Onboarding

    func completeOnboarding() {
        hasCompletedOnboarding = true
        defaults.set(true, forKey: Key.hasCompletedOnboarding)
    }

    // MARK: - Permissions

    func checkPermissionStatus() {
        hasRecordingPermission = AudioSessionManager.shared.hasRecordPermission
    }

    func requestPermission(completion: ((Bool) -> Void)? = nil) {
        AudioSessionManager.shared.requestRecordPermission { [weak self] granted in
            self?.hasRecordingPermission = granted
            completion?(granted)
        }
    }

    // MARK: - Settings

    func setSoundsEnabled(_ enabled: Bool) {
        objectWillChange.send()
        SoundManager.shared.setEnabled(enabled)
        AnalyticsManager.shared.trackCustomEvent(name: "sounds_changed", parameters: ["enabled": enabled])
    }

    func setHapticsEnabled(_ enabled: Bool) {
        hapticsEnabled = enabled
        defaults.set(enabled, forKey: Key.hapticsEnabled)
        AnalyticsManager.shared.trackCustomEvent(name: "haptics_changed", parameters: ["enabled": enabled])
    }

    func setUIMode(_ mode: UIMode) {
        uiMode = mode
        defaults.set(mode.rawValue, forKey: Key.uiMode)
        AnalyticsManager.shared.trackCustomEvent(name: "ui_mode_changed", parameters: ["mode": mode.rawValue])
    }
}
