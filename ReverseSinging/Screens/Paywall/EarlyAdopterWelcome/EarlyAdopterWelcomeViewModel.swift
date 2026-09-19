//
//  EarlyAdopterWelcomeViewModel.swift
//  ReverseSinging
//
//  Behind the note that tells an early adopter the paywall is not for them
//

import Combine

/// Behind the early-adopter welcome.
///
/// Whether the note is due, marking it welcomed, and what comes after it stay with
/// `HomeViewModel`, which decides the order the one-off notes come in. This is only what the
/// note itself does.
@MainActor
final class EarlyAdopterWelcomeViewModel: ObservableObject {

    func onAppear() {
        AnalyticsManager.shared.trackEarlyAdopterWelcomeShown()
    }
}
