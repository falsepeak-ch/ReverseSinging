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
    #if DUBLOON_GAME
    /// Dubloon the Game has its own RevenueCat project ("Dubloon the Game"), so its own
    /// entitlement: buying in one app never unlocks the other.
    static let entitlementID = "dubloon_game_pro"
    #else
    static let entitlementID = "reverso_by_cluso_pro"
    #endif

    /// The one thing on sale: a non-consumable, bought once, kept forever.
    ///
    /// Only used by the fallback paywall, which has to name a product itself
    /// because it runs precisely when the dashboard-configured offering could
    /// not be loaded. The normal path never mentions it: `PaywallView` renders
    /// whatever the current offering contains.
    /// Note the underscores: the App Store product identifier is not the bundle
    /// identifier (`com.falsepeak.reverse-singing-ios`, with hyphens). It has to
    /// match App Store Connect byte for byte or the fetch below returns nothing.
    #if DUBLOON_GAME
    static let lifetimeProductID = "com.falsepeak.dubloon_game.lifetime"
    #else
    static let lifetimeProductID = "com.falsepeak.reverse_singing_ios.lifetime"
    #endif

    // MARK: - API keys

    /// The key a debug build talks to.
    ///
    /// `test_` marks a **Test Store** key. It answers without App Store Connect,
    /// which is what makes the paywall runnable on a simulator before the real
    /// products exist, and it is also why it must never leave a debug build:
    /// RevenueCat rejects App Store submissions configured with one.
    #if DUBLOON_GAME
    private static let testStoreAPIKey = "test_GnnysOMGlrBThoLDdtpRuUGbzhF"
    #else
    private static let testStoreAPIKey = "test_KOOcZkfizJumofnSgaAJRfgMLqM"
    #endif

    /// The public Apple SDK key for App Store builds, from
    /// *Project settings → API keys → Public app-specific key* (`appl_…`).
    ///
    /// Empty until the App Store products are live. While it is empty a release
    /// build runs **without any gating at all** rather than locking everyone out
    /// behind a store it cannot reach — see `AccessController`.
    #if DUBLOON_GAME
    /// Dubloon the Game is its own App Store app, so its own RevenueCat project and key.
    private static let appStoreAPIKey = "appl_rHwNlBKtWilsxeNeasVdLHTxybv"
    #else
    private static let appStoreAPIKey = "appl_aqLqWCwoFekxeQscZrNPuSGmpZp"
    #endif

    /// The key for this build, or `nil` when none is configured.
    static var apiKey: String? {
        #if DEBUG
        // `-useAppStorePurchases YES` points a debug build at the real products in the App
        // Store sandbox, to check the live configuration without shipping a build.
        if UserDefaults.standard.bool(forKey: "useAppStorePurchases") { return appStoreAPIKey }
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
