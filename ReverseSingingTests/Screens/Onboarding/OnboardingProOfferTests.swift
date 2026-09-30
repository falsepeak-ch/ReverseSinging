//
//  OnboardingProOfferTests.swift
//  ReverseSingingTests
//
//  The last onboarding page: buy Dubloon Pro now, or skip it for now
//

import Testing
import Foundation
@testable import ReverseSinging

/// These set the app-wide access state, as `HomeViewModelTests` does, so they are part of
/// that serialized suite: two suites changing the one singleton at once would race.
extension HomeViewModelTests {

    private func onLastPage(access state: AccessState, _ body: (OnboardingViewModel, AppViewModel) -> Void) {
        let access = AccessController.shared
        let previous = access.state
        access.overrideStateForTesting(state)
        defer { access.overrideStateForTesting(previous) }

        let name = "OnboardingProOfferTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        let app = AppViewModel(defaults: defaults)
        let viewModel = OnboardingViewModel(app: app)
        viewModel.currentPage = viewModel.pages.count - 1
        body(viewModel, app)
    }

    /// Someone without Dubloon Pro is offered it on the last page, and nowhere before it.
    @Test func theLastPageOffersProToSomeoneWithoutIt() {
        onLastPage(access: .locked) { viewModel, _ in
            #expect(viewModel.offersPro)

            viewModel.currentPage = 0
            #expect(!viewModel.offersPro)
        }
    }

    /// The main button opens the paywall and does not end onboarding by itself.
    @Test func buyingOpensThePaywallAndStaysOnThePage() {
        onLastPage(access: .locked) { viewModel, app in
            viewModel.primaryTapped()

            #expect(viewModel.isPaywallPresented)
            #expect(!app.hasCompletedOnboarding)
        }
    }

    /// Skipping costs nothing: it goes straight into the app.
    @Test func skippingForNowOpensTheApp() {
        onLastPage(access: .locked) { viewModel, app in
            viewModel.finishOnboarding()

            #expect(app.hasCompletedOnboarding)
            #expect(!viewModel.isPaywallPresented)
        }
    }

    /// A purchase made from the paywall this page opened ends onboarding.
    @Test func buyingFromThePaywallOpensTheApp() {
        onLastPage(access: .locked) { viewModel, app in
            viewModel.primaryTapped()

            AccessController.shared.overrideStateForTesting(.unlocked(.entitlement))

            #expect(!viewModel.isPaywallPresented)
            #expect(app.hasCompletedOnboarding)
        }
    }

    /// An owner or an early adopter has nothing to be sold: the button just continues.
    @Test(arguments: [AccessState.unlocked(.entitlement), .unlocked(.earlyAdopter)])
    func someoneWithEverythingJustContinues(state: AccessState) {
        onLastPage(access: state) { viewModel, app in
            #expect(!viewModel.offersPro)

            viewModel.primaryTapped()

            #expect(!viewModel.isPaywallPresented)
            #expect(app.hasCompletedOnboarding)
        }
    }
}
