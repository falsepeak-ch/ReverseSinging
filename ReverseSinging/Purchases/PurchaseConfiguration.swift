//
//  PurchaseConfiguration.swift
//  ReverseSinging
//
//  The identifiers the RevenueCat integration is keyed on, and the rule that
//  decides which API key a build talks to.
//

import Foundation

/// Everything the store integration needs to know that is not code.
///
/// The identifiers here have to match the RevenueCat dashboard exactly. They are
/// gathered in one file so a rename in the dashboard is a one-line change rather
/// than a hunt through view code.
nonisolated enum PurchaseConfiguration {

    // MARK: - Dashboard identifiers

    /// The entitlement that unlocks the app. Configured under
    /// *Product catalog → Entitlements*, and attached to every product that
    /// should grant access.
    static let entitlementID = "reverso_by_cluso_pro"

    /// The one thing on sale: a non-consumable, bought once, kept forever.
    ///
    /// Only used by the fallback paywall, which has to name a product itself
    /// because it runs precisely when the dashboard-configured offering could
    /// not be loaded. The normal path never mentions it: `PaywallView` renders
    /// whatever the current offering contains.
    /// Note the underscores: the App Store product identifier is not the bundle
    /// identifier (`com.falsepeak.reverse-singing-ios`, with hyphens). It has to
    /// match App Store Connect byte for byte or the fetch below returns nothing.
    static let lifetimeProductID = "com.falsepeak.reverse_singing_ios.lifetime"

    // MARK: - API keys

    /// The key a debug build talks to.
    ///
    /// `test_` marks a **Test Store** key. It answers without App Store Connect,
    /// which is what makes the paywall runnable on a simulator before the real
    /// products exist, and it is also why it must never leave a debug build:
    /// RevenueCat rejects App Store submissions configured with one.
    private static let testStoreAPIKey = "test_KOOcZkfizJumofnSgaAJRfgMLqM"

    /// The public Apple SDK key for App Store builds, from
    /// *Project settings → API keys → Public app-specific key* (`appl_…`).
    ///
    /// Empty until the App Store products are live. While it is empty a release
    /// build runs **without any gating at all** rather than locking everyone out
    /// behind a store it cannot reach — see `AccessController`.
    private static let appStoreAPIKey = "appl_aqLqWCwoFekxeQscZrNPuSGmpZp"

    /// The key for this build, or `nil` when none is configured.
    static var apiKey: String? {
        #if DEBUG
        return testStoreAPIKey
        #else
        return appStoreAPIKey.isEmpty ? nil : appStoreAPIKey
        #endif
    }

    /// Whether this build is pointed at the Test Store rather than the App Store.
    ///
    /// Surfaced in the settings screen so a TestFlight-looking debug build cannot
    /// be mistaken for the real thing while someone is testing a purchase.
    static var isUsingTestStore: Bool {
        apiKey?.hasPrefix("test_") ?? false
    }
}
