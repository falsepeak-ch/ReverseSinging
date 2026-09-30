//
//  BoothCamPrimerViewModelTests.swift
//  ReverseSingingTests
//
//  What the camera explanation may offer, by where the permission stands
//

import Testing
import Foundation
@testable import ReverseSinging

@Suite("Booth Cam Primer View Model") @MainActor
struct BoothCamPrimerViewModelTests {

    private func makeViewModel(_ permission: BoothRecorder.CameraPermission) -> BoothCamPrimerViewModel {
        BoothCamPrimerViewModel(permission: permission, onEnabled: {}, onDismiss: {})
    }

    /// App Review guideline 5.1.1(iv): an explanation shown before a system prompt always
    /// leads to that prompt. With the camera never asked for, the dialog has no other way out.
    @Test func anExplanationBeforeThePromptHasOneWayOut() {
        let viewModel = makeViewModel(.unasked)

        #expect(viewModel.leadsToSystemPrompt)
        #expect(!viewModel.isRefused)
    }

    /// Once the system has an answer there is no prompt to lead to, and the dialog can be
    /// closed like any other.
    @Test(arguments: [BoothRecorder.CameraPermission.granted, .refused])
    func afterAnAnswerTheDialogCanBeClosed(permission: BoothRecorder.CameraPermission) {
        #expect(!makeViewModel(permission).leadsToSystemPrompt)
    }

    /// A refusal from before is the one case where pointing at Settings is right.
    @Test func anEarlierRefusalPointsAtSettings() {
        #expect(makeViewModel(.refused).isRefused)
        #expect(!makeViewModel(.granted).isRefused)
    }
}
