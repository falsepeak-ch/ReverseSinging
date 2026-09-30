//
//  OnboardingViewModel.swift
//  ReverseSinging
//
//  The onboarding pages, and finishing
//

import SwiftUI
import Combine

/// Drives onboarding: which page is up, and handing the user over to the app once it is done.
///
/// There is no microphone page. Someone who has not seen the app yet should be free to decide
/// later, so nothing is asked here: each game asks the first time record is pressed, behind
/// `MicrophonePrimer`'s explanation, when it is obvious what the microphone is for.
@MainActor
final class OnboardingViewModel: ObservableObject {

    @Published var currentPage = 0

    private let app: AppViewModel

    let pages: [OnboardingPage] = [
        OnboardingPage(
            imageName: "microphone",
            title: Strings.Onboarding.welcomeTitle,
            description: Strings.Onboarding.welcomeMessage,
            matteColor: Color.rsSurface1
        ),
        OnboardingPage(
            imageName: "radio",
            title: Strings.Onboarding.howItWorksTitle,
            description: Strings.Onboarding.howItWorksMessage,
            matteColor: Color.rsSurface1
        ),
        // The second game gets its own page: dubbing is nothing like reverse
        // singing, and the "bring your own files" part is better said here than
        // discovered at the content gate.
        OnboardingPage(
            imageName: "clapperboard",
            title: Strings.Onboarding.dubTitle,
            description: Strings.Onboarding.dubMessage,
            matteColor: Color.rsSurface1
        ),
        // What costs money, and why, said before anyone meets a lock: there are no ads, no
        // account and no tracking to pay for the app, so Pro does. Said here it is an
        // explanation. Left for the paywall to say, it reads as a surprise. It comes last,
        // once the games it pays for have been shown.
        OnboardingPage(
            imageName: "settings-unlock",
            title: Strings.Onboarding.proTitle,
            description: Strings.Onboarding.proMessage,
            matteColor: Color.rsSurface1
        )
    ]

    init(app: AppViewModel) {
        self.app = app
    }

    /// The page whose button ends onboarding.
    var isOnLastPage: Bool { currentPage == pages.count - 1 }

    /// The one button under the pages: on, or into the app from the last of them.
    func continueTapped() {
        isOnLastPage ? finishOnboarding() : nextPage()
    }

    // MARK: - Screen

    func onAppear() {
        AnalyticsManager.shared.trackOnboardingStarted()
    }

    // MARK: - Navigation

    func nextPage() {
        withAnimation(.rsSpring) {
            if currentPage < pages.count - 1 {
                currentPage += 1
            }
        }
        HapticManager.shared.light()
    }

    func finishOnboarding() {
        withAnimation(.rsSpring) {
            // The reverse game opens in its simple skin. The picker that used to sit
            // here is gone: choosing between two control rooms before seeing either
            // was the page everyone flicked past. Settings still offers the choice.
            app.setUIMode(.simple)
            AnalyticsManager.shared.trackOnboardingCompleted()
            app.completeOnboarding()
        }
    }
}
