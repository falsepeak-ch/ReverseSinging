//
//  MacE2EProbe.swift
//  DubloonMac
//
//  Where the end-to-end run finds the models the screens create for themselves. Debug only.
//

#if DEBUG
import Foundation

/// The screens' own view models, registered as they appear, so the end-to-end run can read
/// what the window is showing without reaching into SwiftUI's storage. Weak: a screen that
/// goes away takes its model with it, and the run sees that as nil.
@MainActor
final class MacE2EProbe {
    static let shared = MacE2EProbe()

    weak var welcome: MacWelcomeViewModel?
    weak var reverse: ReverseStudioViewModel?
    weak var dubEditor: DubEditorViewModel?
    weak var imitate: ImitateStudioViewModel?

    /// True for a run started with `-macE2E YES`.
    nonisolated static var isActive: Bool {
        UserDefaults.standard.bool(forKey: "macE2E")
    }
}
#endif
