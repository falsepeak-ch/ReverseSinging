//
//  SoundLibraryViewModel.swift
//  ReverseSinging
//
//  The Sound Imitation library: which sound is open, and how each has gone so far
//

import Combine
import DubScoring
import SwiftUI

@MainActor
final class SoundLibraryViewModel: ObservableObject {

    /// The sound pushed onto the stack. Nil on the library itself.
    @Published var selectedSound: ImitationSound?

    let categories: [ImitationCategory] = ImitationCategory.allCases

    private let progress: ImitationProgressStore
    private var cancellables = Set<AnyCancellable>()

    init(progress: ImitationProgressStore = .shared) {
        self.progress = progress
        progress.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    func sounds(in category: ImitationCategory) -> [ImitationSound] {
        ImitationSoundLibrary.sounds(in: category)
    }

    func best(for sound: ImitationSound) -> Double? {
        progress.best(for: sound)
    }

    func grade(for sound: ImitationSound) -> DubGrade? {
        progress.best(for: sound).map(DubGrade.forScore)
    }

    func open(_ sound: ImitationSound) {
        HapticManager.shared.light()
        selectedSound = sound
    }

    func onAppear() {
        AnalyticsManager.shared.trackScreenViewed(screenName: "ImitateLibrary")
    }
}
