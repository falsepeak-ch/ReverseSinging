//
//  AppearancePreference.swift
//  ReverseSinging
//
//  Light, dark, or whatever the device is set to
//

import SwiftUI
import Combine
#if os(iOS)
import UIKit
#endif

/// The look the person picked in Settings.
nonisolated enum AppearanceMode: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: Strings.Settings.appearanceSystem
        case .light: Strings.Settings.appearanceLight
        case .dark: Strings.Settings.appearanceDark
        }
    }

    var symbol: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }

    /// What the window is told to prefer. Nil follows the device.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// App-wide, so the switch in Settings and the root that applies it are the same switch.
///
/// The palette in `Colors.swift` has a light and a dark value for every token, so the choice
/// is made once, at the root, and every screen follows. The screens that show a film, the
/// recorder and the scene player, stay dark whatever is chosen: a picture reads best in a
/// dark room, which is why editing suites are dark.
@MainActor
final class AppearancePreference: ObservableObject {

    static let shared = AppearancePreference()

    private static let key = "appearance"

    @Published private(set) var mode: AppearanceMode

    private init() {
        mode = UserDefaults.standard.string(forKey: Self.key).flatMap(AppearanceMode.init) ?? .system
    }

    func set(_ mode: AppearanceMode) {
        guard mode != self.mode else { return }
        self.mode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: Self.key)
        applyToWindows()
        AnalyticsManager.shared.trackCustomEvent(name: "appearance_changed", parameters: ["mode": mode.rawValue])
    }

    /// Sets the style on the windows, and on every screen presented in them, as well as through
    /// SwiftUI. `preferredColorScheme` alone stamps its choice on a sheet that is already up and
    /// never takes it back, so Settings, the very sheet the switch is in, would keep the old
    /// look; and going back to "no preference" can leave a window stuck until the next launch.
    /// Run again a turn later so it lands after SwiftUI has made its own pass.
    func applyToWindows() {
        #if os(iOS)
        apply(style)
        DispatchQueue.main.async { [self] in apply(style) }
        #endif
    }

    #if os(iOS)
    private var style: UIUserInterfaceStyle {
        switch mode {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }

    private func apply(_ style: UIUserInterfaceStyle) {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = style
                var presented = window.rootViewController?.presentedViewController
                while let controller = presented {
                    // A screen that holds itself dark says so through SwiftUI's environment,
                    // not through this override, so every presented screen can follow.
                    controller.overrideUserInterfaceStyle = style
                    presented = controller.presentedViewController
                }
            }
        }
    }
    #endif
}

extension View {
    /// A screen that shows a film: the recorder and the scene player. Dark whatever the app is
    /// set to, the way an edit suite keeps the lights down around the picture.
    func cinemaAppearance() -> some View {
        environment(\.colorScheme, .dark)
            .background(Color.rsSurface0.environment(\.colorScheme, .dark).ignoresSafeArea())
    }

    /// The Pro paywall, designed in the RevenueCat dashboard for a dark stage, stays on one.
    func paywallAppearance() -> some View {
        environment(\.colorScheme, .dark)
    }
}
