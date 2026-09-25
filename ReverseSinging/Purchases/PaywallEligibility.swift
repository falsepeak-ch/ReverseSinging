//
//  PaywallEligibility.swift
//  ReverseSinging
//
//  Whether someone downloaded the app late enough to be asked to pay for it.
//

import Foundation

/// The one rule about who may be shown a paywall: people who first downloaded the
/// app **on or after** the console's cutoff, and nobody else.
///
/// It needs two facts: when this Apple Account first downloaded the app, and what
/// the cutoff is. A missing fact is its own answer, `undetermined`, and is never
/// rounded to `eligible` — a paywall in front of someone who was here first is the
/// mistake this type exists to prevent, and "we could not tell" is exactly when it
/// would otherwise happen.
///
/// **The fallback.** The store does not always report a download date. When the
/// caller says it has asked and got none, the app's own first-launch date stands in
/// — in one direction only. A first launch on or after the cutoff makes someone
/// `eligible`; a first launch before it proves nothing (`undetermined`), and in
/// particular never makes anyone `exempt`. The exemption is permanent and the
/// device clock can be set back, so it is only ever granted on Apple's date.
///
/// The price of the fallback is known and accepted: someone who was here before the
/// cutoff, reinstalls, and whose receipt never loads is dated from the reinstall and
/// gated until the receipt arrives or they tap Restore.
nonisolated enum PaywallEligibility: Equatable {
    /// Downloaded before the cutoff. Never pays, never sees a trial or a paywall.
    case exempt
    /// Downloaded on the cutoff or later. Gets the trial, then the paywall.
    case eligible
    /// The download date or the cutoff is not known yet. Treated as not gated.
    case undetermined

    /// - Parameters:
    ///   - downloadedAt: the original download date from the App Store receipt, or
    ///     nil while the store has not reported one.
    ///   - firstLaunchedAt: the app's own first-launch date, passed **only** once
    ///     the store has been asked for a download date and had none. Nil means the
    ///     fallback is not in play. Ignored whenever `downloadedAt` is known.
    ///   - cutoff: the console's `paywall_release_date`, or nil while the console
    ///     has not supplied a readable one. The instant is midnight UTC at the
    ///     start of that day, so the day itself counts as "on or after".
    /// The start of the day version 1.0.0 was created in App Store Connect (2025-10-26 UTC).
    /// Nobody downloaded the app before it.
    static let storeDebut = Date(timeIntervalSince1970: 1_761_436_800)

    /// The store's download date, or nil when it cannot be a real one.
    ///
    /// Sandbox and TestFlight receipts report every download as 2013-08-01, twelve years
    /// before the app existed. Read at face value that makes every tester, and App Review,
    /// an early adopter: free for life, with no way to reach the purchase screen. Dropping
    /// it leaves them on the first-launch fallback, which gates a fresh install.
    static func plausibleDownloadDate(_ date: Date?) -> Date? {
        guard let date, date >= storeDebut else { return nil }
        return date
    }

    init(downloadedAt: Date?, firstLaunchedAt: Date? = nil, cutoff: Date?) {
        guard let cutoff else {
            self = .undetermined
            return
        }
        if let downloadedAt {
            self = downloadedAt < cutoff ? .exempt : .eligible
        } else if let firstLaunchedAt, firstLaunchedAt >= cutoff {
            self = .eligible
        } else {
            self = .undetermined
        }
    }
}
