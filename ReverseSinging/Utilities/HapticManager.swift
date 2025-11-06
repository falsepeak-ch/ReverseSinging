//
//  HapticManager.swift
//  ReverseSinging
//
//  Haptic feedback manager
//

import UIKit

final class HapticManager {
    static let shared = HapticManager()

    private init() {}

    // MARK: - Enabled Check

    private var isEnabled: Bool {
        // Check UserDefaults, default to true if not set
        if UserDefaults.standard.object(forKey: "hapticsEnabled") != nil {
            return UserDefaults.standard.bool(forKey: "hapticsEnabled")
        }
        return true
    }

    // MARK: - Impact Feedback

    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    func light() {
        impact(.light)
    }

    func medium() {
        impact(.medium)
    }

    func heavy() {
        impact(.heavy)
    }

    func rigid() {
        impact(.rigid)
    }

    func soft() {
        impact(.soft)
    }

    // MARK: - Notification Feedback

    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }

    func success() {
        notification(.success)
    }

    func warning() {
        notification(.warning)
    }

    func error() {
        notification(.error)
    }

    // MARK: - Selection Feedback

    func selection() {
        guard isEnabled else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}
