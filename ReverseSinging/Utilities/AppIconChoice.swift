//
//  AppIconChoice.swift
//  ReverseSinging
//
//  The Home Screen icons Dubloon ships, and switching between them.
//

#if os(iOS)
import Combine
import SwiftUI
import UIKit

/// One of the app's Home Screen icons.
///
/// The primary icon is the Halloween one for now (`AppIconHalloween.icon`,
/// `GameAppIconHalloween.icon` in Dubloon the Game, set by `ASSETCATALOG_COMPILER_APPICON_NAME`);
/// the classic icon is an alternate, listed in `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`.
/// When the season ends, swap the two build settings and the `alternateName`s below. A new icon
/// needs its `.icon` file, that setting, a case here, and a `settings-icon-<case>` preview
/// (`settings-icon-game-<case>` in the game).
enum AppIconChoice: String, CaseIterable, Identifiable {
    case halloween
    case classic

    var id: String { rawValue }

    /// The alternate icon's name for `setAlternateIconName`; nil for the primary icon.
    var alternateName: String? {
        switch self {
        case .halloween: return nil
        #if DUBLOON_GAME
        case .classic: return "GameAppIcon"
        #else
        case .classic: return "AppIcon"
        #endif
        }
    }

    var title: String {
        switch self {
        case .halloween: return Strings.Settings.appIconHalloween
        case .classic: return Strings.Settings.appIconClassic
        }
    }

    /// The preview drawn in Settings.
    var previewAssetName: String {
        #if DUBLOON_GAME
        return "settings-icon-game-\(rawValue)"
        #else
        return "settings-icon-\(rawValue)"
        #endif
    }
}

/// Which icon is on the Home Screen. The system remembers the choice itself; this mirrors it so
/// the picker can follow along.
@MainActor
final class AppIconPreference: ObservableObject {

    static let shared = AppIconPreference()

    @Published private(set) var current: AppIconChoice

    init() {
        let name = UIApplication.shared.alternateIconName
        current = AppIconChoice.allCases.first { $0.alternateName == name } ?? .halloween
    }

    var isSupported: Bool { UIApplication.shared.supportsAlternateIcons }

    /// Swaps the Home Screen icon. The system shows its own confirmation alert.
    func set(_ choice: AppIconChoice) {
        guard choice != current, isSupported else { return }
        let previous = current
        current = choice
        Task {
            do {
                try await UIApplication.shared.setAlternateIconName(choice.alternateName)
                AnalyticsManager.shared.trackCustomEvent(name: "app_icon_changed", parameters: ["icon": choice.rawValue])
            } catch {
                CrashReporter.shared.record(error, context: "app_icon_change")
                current = previous
            }
        }
    }
}
#endif
