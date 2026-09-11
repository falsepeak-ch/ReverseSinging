//
//  BoothCamAnnouncementViewModel.swift
//  ReverseSinging
//
//  Behind the note that tells someone who updated that the booth exists
//

import Combine

/// Behind the Booth Cam note.
///
/// Whether the note is due, and marking it shown, stay with `HomeView`, which also decides the
/// order it comes in beside the early-adopter note. This is only what the note itself does.
@MainActor
final class BoothCamAnnouncementViewModel: ObservableObject {

    /// Called when the user wants to go and try it, after the sheet has dismissed itself.
    private let onTryIt: () -> Void

    init(onTryIt: @escaping () -> Void) {
        self.onTryIt = onTryIt
    }

    func onAppear() {
        AnalyticsManager.shared.trackScreenViewed(screenName: "BoothCamAnnouncement")
    }

    func tryIt() {
        onTryIt()
    }
}
