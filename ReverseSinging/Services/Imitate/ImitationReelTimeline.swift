//
//  ImitationReelTimeline.swift
//  ReverseSinging
//
//  When each part of an imitation video happens
//

import Foundation

/// The four acts of an imitation video and where each one starts, in seconds.
///
/// One value shared by the picture and the sound, so the stamp lands on its thud and the
/// performer's mouth moves with their voice. Nothing else decides a time.
nonisolated struct ImitationReelTimeline: Sendable {

    /// "Can you sound like a…" and the sound's name.
    static let introDuration: TimeInterval = 1.6
    /// A breath between the original and the attempt.
    static let gapAfterReference: TimeInterval = 0.4
    /// The score counting up, the stamp, the confetti, the sign-off.
    static let revealDuration: TimeInterval = 3.6
    /// How far into the reveal the stamp lands.
    static let stampDelay: TimeInterval = 1.1

    let referenceStart: TimeInterval
    let referenceDuration: TimeInterval
    let takeStart: TimeInterval
    let takeDuration: TimeInterval
    let revealStart: TimeInterval
    let total: TimeInterval

    var stampTime: TimeInterval { revealStart + Self.stampDelay }

    init(referenceDuration: TimeInterval, takeDuration: TimeInterval) {
        self.referenceDuration = referenceDuration
        self.takeDuration = takeDuration
        referenceStart = Self.introDuration
        takeStart = referenceStart + referenceDuration + Self.gapAfterReference
        revealStart = takeStart + takeDuration
        total = revealStart + Self.revealDuration
    }

    enum Act {
        case intro(TimeInterval)
        case reference(TimeInterval)
        case take(TimeInterval)
        case reveal(TimeInterval)
    }

    /// Which act `time` falls in, and how far into it. The gap after the original belongs to
    /// the original, so its last frame holds rather than cutting to black.
    func act(at time: TimeInterval) -> Act {
        if time < referenceStart { return .intro(time) }
        if time < takeStart { return .reference(time - referenceStart) }
        if time < revealStart { return .take(time - takeStart) }
        return .reveal(time - revealStart)
    }
}
