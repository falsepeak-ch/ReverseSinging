//
//  ImitationScore.swift
//  DubScoring
//
//  How close an impression came to the sound it imitates
//

import Foundation

/// How close someone's impression came to a sound, split into the things a listener hears.
///
/// Each part is 0...100. `pitch` is nil when the sound has no pitch to follow (a sneeze, a
/// burp, a hiss), where marking it would only punish the performer for something that
/// isn't there.
public struct ImitationScore: Codable, Hashable, Sendable {

    /// The bursts and gaps: one honk or two, a long moo or a short one, where it swells.
    public let rhythm: Double

    /// Whether the note moves the way the sound's does: the siren's wail, the laser's drop,
    /// the meow's rise and fall. Measured relative to each voice's own register.
    public let pitch: Double?

    /// Bright or dull, hissy or hummed. The colour of the sound, as far as a voice can reach it.
    public let tone: Double

    /// Whether it lasted about as long.
    public let duration: Double

    /// The single number shown to the user, 0...100.
    public let overall: Double

    /// The band `overall` falls in, on the same ladder as the dub scores.
    public var grade: DubGrade { DubGrade.forScore(overall) }

    public init(rhythm: Double, pitch: Double?, tone: Double, duration: Double) {
        self.rhythm = Self.clamp(rhythm)
        self.pitch = pitch.map(Self.clamp)
        self.tone = Self.clamp(tone)
        self.duration = Self.clamp(duration)
        self.overall = Self.combine(rhythm: self.rhythm, pitch: self.pitch, tone: self.tone, duration: self.duration)
    }

    /// Nothing heard at all.
    public static let silent = ImitationScore(rhythm: 0, pitch: 0, tone: 0, duration: 0)

    /// Rhythm carries the most because it is what makes an impression recognisable at all;
    /// pitch next, because it is what makes the funny ones funny. When there is no pitch to
    /// follow its share is spread over the others rather than handed out for free.
    ///
    /// The blend is bent upward a little (x^0.85): a party game should feel generous in the
    /// middle and still keep the top for the genuinely uncanny.
    private static func combine(rhythm: Double, pitch: Double?, tone: Double, duration: Double) -> Double {
        var parts: [(value: Double, weight: Double)] = [(rhythm, 0.35), (tone, 0.20), (duration, 0.15)]
        if let pitch { parts.append((pitch, 0.30)) }

        let totalWeight = parts.reduce(0) { $0 + $1.weight }
        let blended = parts.reduce(0) { $0 + $1.value * $1.weight } / totalWeight / 100
        let curved = pow(max(0, blended), 0.85) * 100
        return (curved * 10).rounded() / 10
    }

    private static func clamp(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(100, max(0, value))
    }
}
