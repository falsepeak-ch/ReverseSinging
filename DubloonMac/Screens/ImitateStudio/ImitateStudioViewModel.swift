//
//  ImitateStudioViewModel.swift
//  DubloonMac
//
//  Sound Imitation as a browser of sounds beside the stage for the one selected
//

import SwiftUI
import Combine

/// Drives the imitation studio.
///
/// The library and the challenge are the iPhone's models. There they are two screens, one
/// pushed on the other; here the browser stays on screen and choosing a sound swaps the stage
/// beside it, so the challenge is built when a sound is selected and closed when another is.
@MainActor
final class ImitateStudioViewModel: ObservableObject {

    let library = SoundLibraryViewModel()

    @Published private(set) var challenge: ImitationChallengeViewModel?

    /// The browser's filter; nil lists every category. Remembered across launches.
    @Published var category: ImitationCategory? {
        didSet { UserDefaults.standard.set(category?.rawValue, forKey: Self.categoryKey) }
    }

    private static let categoryKey = "mac.imitate.category"

    private var cancellables = Set<AnyCancellable>()
    private var challengeCancellable: AnyCancellable?

    init() {
        category = UserDefaults.standard.string(forKey: Self.categoryKey).flatMap(ImitationCategory.init(rawValue:))
        library.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    var selectedSound: ImitationSound? { challenge?.sound }

    // MARK: - Screen

    func onAppear() {
        library.onAppear()
        if challenge == nil, let first = visibleSounds.first {
            select(first)
        }
    }

    func onDisappear() {
        challenge?.onDisappear()
    }

    // MARK: - Sounds

    func select(_ sound: ImitationSound) {
        guard sound != selectedSound, !(challenge?.isBusy ?? false) else { return }
        challenge?.onDisappear()

        let model = ImitationChallengeViewModel(sound: sound)
        challengeCancellable = model.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
        challenge = model
        model.onAppear()
        HapticManager.shared.light()
    }

    /// The sounds the browser lists, in its order.
    var visibleSounds: [ImitationSound] {
        let categories = category.map { [$0] } ?? library.categories
        return categories.flatMap(library.sounds(in:))
    }

    /// ↑ and ↓ from the Playback menu: the neighbouring sound in the browser.
    func selectNeighbour(_ step: Int) {
        let sounds = visibleSounds
        guard !sounds.isEmpty else { return }
        let index = selectedSound.flatMap { sounds.firstIndex(of: $0) } ?? -step
        let target = min(max(index + step, 0), sounds.count - 1)
        select(sounds[target])
    }

    func select(id: ImitationSound.ID?) {
        guard let id, let sound = ImitationSoundLibrary.sound(id: id) else { return }
        select(sound)
    }

    // MARK: - Dashboard

    var lamp: ProDashboard.Lamp {
        switch challenge?.phase {
        case .countingIn: .countIn
        case .recording: .recording
        default: challenge?.playingClip != nil ? .playing : .idle
        }
    }

    var timecode: String {
        guard let challenge else { return TimeInterval(0).proTimecode }
        return challenge.phase == .recording
            ? challenge.recordingElapsed.proTimecode
            : challenge.sound.duration.proTimecode
    }
}
