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
/// The last page says what Dubloon Pro is for, and to someone who does not have it, it offers
/// the two honest answers side by side: buy it now, or skip it for now. Skipping costs
/// nothing: the free games play, and the menu keeps the offer where it can be found.
///
/// There is no microphone page. Someone who has not seen the app yet should be free to decide
/// later, so nothing is asked here: each game asks the first time record is pressed, behind
/// `MicrophonePrimer`'s explanation, when it is obvious what the microphone is for.
@MainActor
final class OnboardingViewModel: ObservableObject {

    @Published var currentPage = 0

    /// The paywall, opened from the last page.
    @Published var isPaywallPresented = false

    private let app: AppViewModel
    private let access: AccessController
    private var cancellables = Set<AnyCancellable>()

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

    init(app: AppViewModel, access: AccessController = .shared) {
        self.app = app
        self.access = access

        access.$state
            .removeDuplicates()
            .sink { [weak self] state in self?.accessStateDidChange(state) }
            .store(in: &cancellables)
    }

    /// The page whose button ends onboarding.
    var isOnLastPage: Bool { currentPage == pages.count - 1 }

    /// Whether the page on screen is the Pro page in front of someone who could buy it. It
    /// then carries two buttons, buy and skip, in place of Continue. An owner or an early
    /// adopter has nothing to be sold and just continues.
    var offersPro: Bool { isOnLastPage && isLocked }

    /// Mirrors `AccessController.isLocked`, so the buttons follow a purchase or a restore
    /// that lands while the page is up.
    @Published private(set) var isLocked = false

    /// The main button under the pages.
    func primaryTapped() {
        offersPro ? showPaywall() : continueTapped()
    }

    /// On, or into the app from the last page.
    func continueTapped() {
        isOnLastPage ? finishOnboarding() : nextPage()
    }

    func showPaywall() {
        HapticManager.shared.light()
        isPaywallPresented = true
    }

    /// Fed the new value rather than reading `access.isLocked`, which has not changed yet
    /// when a `@Published` sink fires.
    private func accessStateDidChange(_ state: AccessState) {
        isLocked = state == .locked
        // Bought from the paywall this page opened: there is nothing left to explain.
        if isPaywallPresented, state == .unlocked(.entitlement) {
            isPaywallPresented = false
            finishOnboarding()
        }
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
