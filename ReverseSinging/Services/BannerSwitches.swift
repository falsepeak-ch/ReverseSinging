//
//  BannerSwitches.swift
//  ReverseSinging
//
//  Remote off switches for promotional banners, read from Firebase Remote Config.
//

import Combine
import Foundation
#if canImport(FirebaseRemoteConfig)
import FirebaseRemoteConfig
#endif

/// Whether each promotional banner may show, as Firebase Remote Config says.
///
/// Only banners are switched from the console. Who pays, and for what, stays fixed in the
/// binary (`AccessController`): a wrong console value must never change what anyone is
/// charged or what they can play. The worst a value here can do is hide an offer.
///
/// Every switch defaults to on, which is also the answer offline, before the first fetch,
/// and on a target built without Remote Config (the Mac). A change in the console reaches
/// running apps within seconds through Remote Config's realtime updates.
///
/// Console parameters (Boolean, project reverso-87e1a, one per banner; condition on the
/// iOS app to switch Dubloon and Dubloon the Game separately):
/// - `halloween_banner_enabled`: the Halloween deal over the games.
@MainActor
final class BannerSwitches: ObservableObject {

    static let shared = BannerSwitches()

    nonisolated static let halloweenKey = "halloween_banner_enabled"

    @Published private(set) var isHalloweenBannerEnabled = true

    private var hasStarted = false

    #if canImport(FirebaseRemoteConfig)
    private var listener: ConfigUpdateListenerRegistration?
    #endif

    /// Fetches the switches and listens for changes. Call once, after `FirebaseApp.configure()`.
    func start() {
        #if canImport(FirebaseRemoteConfig)
        guard !hasStarted else { return }
        hasStarted = true

        let config = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        #if DEBUG
        settings.minimumFetchInterval = 0
        #else
        settings.minimumFetchInterval = 3_600
        #endif
        config.configSettings = settings
        config.setDefaults([Self.halloweenKey: NSNumber(value: true)])
        // The last fetched values, from disk, before the network answers.
        apply(config)

        Task {
            do {
                _ = try await config.fetchAndActivate()
            } catch {
                CrashReporter.shared.log("remote_config_fetch_failed")
            }
            apply(config)
        }

        listener = Self.listen(to: config) { [weak self] in
            self?.apply(config)
        }
        #endif
    }

    #if canImport(FirebaseRemoteConfig)
    private func apply(_ config: RemoteConfig) {
        isHalloweenBannerEnabled = config.configValue(forKey: Self.halloweenKey).boolValue
    }

    /// Realtime updates arrive on a background queue. The handler is built here, outside the
    /// main actor, so Swift does not assume it runs on the main thread (it would trap); it
    /// activates the update and hops to the main actor itself.
    nonisolated private static func listen(
        to config: RemoteConfig,
        onChange: @escaping @MainActor @Sendable () -> Void
    ) -> ConfigUpdateListenerRegistration {
        config.addOnConfigUpdateListener { update, error in
            guard error == nil, update?.updatedKeys.contains(halloweenKey) == true else { return }
            config.activate { _, _ in
                Task { @MainActor in onChange() }
            }
        }
    }
    #endif
}
