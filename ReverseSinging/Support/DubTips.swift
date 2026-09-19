//
//  DubTips.swift
//  ReverseSinging
//
//  The first-run coaching for the dub game, one tip at a time
//

import SwiftUI
import TipKit

/// What a first-time dubber gets told, and in what order.
///
/// TipKit shows every eligible tip the moment it is eligible, and three popovers landing on
/// one screen together is exactly the wall of help this is meant not to be. So the tips take
/// turns through one counter: each is eligible at its own number, and closing one, or doing
/// the thing it describes, moves the counter on. TipKit remembers what has been closed, so
/// none of them ever comes back.
///
/// Three, and no more. Recording is the game, the booth is the one option worth pointing at,
/// and hearing yourself in the film is the payoff. Everything else is there to be found.
enum DubTips {

    /// Which tip is up. Persisted by TipKit, like the tips themselves.
    @Parameter static var stage: Int = 0

    /// Whether there is a take to hear yet. The playback tip waits for one: "hear yourself in
    /// the film" is an empty promise on a scene nobody has dubbed.
    @Parameter static var hasRecordedATake: Bool = false

    /// Whether the booth is already on. Someone who has been through the primer has had the
    /// booth explained at length, and a tip on top of that is nagging.
    @Parameter static var isBoothOn: Bool = false

    /// Whether the record screen is up. The playback tip lives on the screen underneath it,
    /// and becomes due the moment the booth tip is closed up there. Left to itself it would
    /// try to present while the cover is still animating away, which SwiftUI drops without
    /// a word, and TipKit would count the tip as shown. So it waits for the cover to be gone.
    @Parameter static var isRecorderOpen: Bool = false

    /// Moves on from `completed`, and only from there, so a tip closed twice, or closed after
    /// the next one is already up, cannot skip a step.
    static func advance(past completed: Int) {
        guard stage == completed else { return }
        stage = completed + 1
        skipBoothTipIfMoot()
    }

    /// Called whenever the booth is switched, and once on arrival.
    static func noteBooth(isOn: Bool) {
        isBoothOn = isOn
        skipBoothTipIfMoot()
    }

    /// Nothing to say about a booth that is already on; straight through to the payoff.
    private static func skipBoothTipIfMoot() {
        if stage == 1, isBoothOn { stage = 2 }
    }
}

// MARK: - The Tips

/// Listen, then record. Anchored to the record button.
struct DubRecordTip: Tip {
    var title: Text { Text(Strings.Dub.Tip.recordTitle) }
    var message: Text? { Text(Strings.Dub.Tip.recordMessage) }
    var image: Image? { Image(systemName: "mic.fill") }

    var rules: [Rule] {
        #Rule(DubTips.$stage) { $0 == 0 }
    }
}

/// The camera key exists. Anchored to it.
struct DubBoothTip: Tip {
    var title: Text { Text(Strings.Dub.Tip.boothTitle) }
    var message: Text? { Text(Strings.Dub.Tip.boothMessage) }
    var image: Image? { Image(systemName: "video.fill") }

    var rules: [Rule] {
        #Rule(DubTips.$stage) { $0 == 1 }
        #Rule(DubTips.$isBoothOn) { $0 == false }
    }
}

/// Your voice is in the scene now. Anchored to Play My Dub, once there is a dub to play.
struct DubPlayDubTip: Tip {
    var title: Text { Text(Strings.Dub.Tip.playDubTitle) }
    var message: Text? { Text(Strings.Dub.Tip.playDubMessage) }
    var image: Image? { Image(systemName: "person.wave.2.fill") }

    var rules: [Rule] {
        #Rule(DubTips.$stage) { $0 == 2 }
        #Rule(DubTips.$hasRecordedATake) { $0 == true }
        #Rule(DubTips.$isRecorderOpen) { $0 == false }
    }
}

// MARK: - Sequencing

extension View {
    /// Moves the counter on when `tip` goes away, however it went: closed, or its action done.
    func advancesDubTips(past stage: Int, when tip: some Tip) -> some View {
        task {
            for await status in tip.statusUpdates {
                if case .invalidated = status { DubTips.advance(past: stage) }
            }
        }
    }

    /// The tips drawn in the editor's own surface rather than the system's white card.
    func dubTipStyle() -> some View {
        self
            .tipBackground(Color.rsSurface2)
            .tipCornerRadius(EditorMetrics.radius)
    }
}
