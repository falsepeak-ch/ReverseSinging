//
//  RemoteConfigService.swift
//  ReverseSinging
//
//  The two numbers the paywall is allowed to change without a release.
//

import Combine
import Foundation
import FirebaseCore
import FirebaseRemoteConfig

/// Firebase Remote Config, narrowed to the paywall's two knobs.
///
/// Both have in-app defaults, so a device that has never reached Firebase — first
/// launch on a plane, a fetch that times out — behaves like the shipped build
/// rather than waiting on the network to decide whether the app works.
@MainActor
final class RemoteConfigService: ObservableObject {

    static let shared = RemoteConfigService()

    // MARK: - Keys

    private enum Key {
        /// How many days of free use a new install gets.
        static let trialLengthInDays = "trial_length_days"
        /// The kill switch. Set to `false` in the console to stop gating anyone,
        /// which is the way out if the paywall goes wrong after release.
        static let paywallEnabled = "paywall_enabled"
        /// `YYYY-MM-DD`. Anyone whose Apple Account downloaded the app before this
        /// never pays. See `EarlyAdopter`.
        static let paywallReleaseDate = "paywall_release_date"
    }

    // MARK: - Defaults

    /// What ships in the binary, used until a fetch succeeds.
    private enum Default {
        static let trialLengthInDays = 7
        static let paywallEnabled = true
        /// The date this shipped, as a last resort.
        ///
        /// The real cutoff is the App Store release date, which is not knowable at
        /// build time — Apple decides it — which is exactly why it comes from the
        /// console. This default only has to hold for the seconds before the first
        /// fetch lands, and the grant is re-evaluated once it does.
        static let paywallReleaseDate = "2026-09-04"
    }

    /// A console typo should not hand out a decade of free use, nor zero days to
    /// everyone at once. Values outside this are clamped into it.
    private static let allowedTrialLength = 0...365

    // MARK: - Published

    /// The free window's length, in days.
    @Published private(set) var trialLengthInDays: Int = Default.trialLengthInDays

    /// Whether anyone is gated at all.
    @Published private(set) var isPaywallEnabled: Bool = Default.paywallEnabled

    /// The grandfather cutoff: a download before this date never pays.
    @Published private(set) var paywallReleaseDate: Date =
        RemoteConfigService.parseReleaseDate(Default.paywallReleaseDate) ?? .distantFuture

    /// Whether a fetch has landed. Until it has, the values above are the shipped
    /// defaults rather than the console's.
    @Published private(set) var hasActivated = false

    private var remoteConfig: RemoteConfig?

    private init() {}

    // MARK: - Loading

    /// Reads the cached values, then fetches.
    ///
    /// The cached read is synchronous and is what the first frame uses; the fetch
    /// updates the published values if the console disagrees. Safe to call more
    /// than once.
    func start() async {
        // Remote Config needs a configured `FirebaseApp`. A screenshot run
        // deliberately never configures one, so there is nothing to talk to.
        guard FirebaseApp.app() != nil else { return }

        let config = remoteConfig ?? RemoteConfig.remoteConfig()
        remoteConfig = config

        config.setDefaults([
            Key.trialLengthInDays: Default.trialLengthInDays as NSNumber,
            Key.paywallEnabled: Default.paywallEnabled as NSNumber,
            Key.paywallReleaseDate: Default.paywallReleaseDate as NSString
        ])

        let settings = RemoteConfigSettings()
        #if DEBUG
        // Otherwise a console change takes up to twelve hours to show up while
        // someone is standing there trying to test it.
        settings.minimumFetchInterval = 0
        #else
        settings.minimumFetchInterval = 3600
        #endif
        config.configSettings = settings

        // Whatever a previous launch fetched, applied before the network is asked.
        apply(config)

        do {
            _ = try await config.fetchAndActivate()
            apply(config)
            hasActivated = true
        } catch {
            // Nothing to do but keep the cached values, which are already applied.
            CrashReporter.shared.record(
                error, context: "remote_config_fetch", keys: ["source": "paywall"]
            )
        }
    }

    private func apply(_ config: RemoteConfig) {
        let fetchedLength = config[Key.trialLengthInDays].numberValue.intValue
        trialLengthInDays = min(
            max(fetchedLength, Self.allowedTrialLength.lowerBound),
            Self.allowedTrialLength.upperBound
        )
        isPaywallEnabled = config[Key.paywallEnabled].boolValue

        // A value the console cannot parse keeps whatever we already had. The
        // alternative — treating an unparseable date as "the beginning of time" —
        // would quietly un-grandfather every early adopter who reinstalls, from a
        // typo, with no error anywhere.
        if let fetched = Self.parseReleaseDate(config[Key.paywallReleaseDate].stringValue) {
            paywallReleaseDate = fetched
        }
    }

    /// Parses the console's `YYYY-MM-DD` into a UTC date, or nil if it is not one.
    ///
    /// Fixed format and POSIX locale deliberately: the device's own locale and
    /// calendar have no business interpreting a value an operator typed into a
    /// dashboard, and a Buddhist or Japanese calendar on the reader's phone would
    /// otherwise shift the cutoff by centuries.
    nonisolated static func parseReleaseDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }
}
