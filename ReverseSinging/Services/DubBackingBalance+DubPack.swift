//
//  DubBackingBalance+DubPack.swift
//  ReverseSinging
//
//  A pack's bed, placed under that pack's own dialogue
//

import AVFoundation
import DubAudio

nonisolated extension DubBackingBalance {

    /// How loud a pack's dialogue is, from the film's own recording of each of its lines.
    static func dialogueLevel(of pack: DubPack) -> Float? {
        dialogueLevel(ofReferencesAt: pack.lines.map { pack.referenceAudioURL(for: $0) })
    }

    /// Measures a pack's dialogue and its bed under that dialogue, and places one under the
    /// other for the whole scene.
    static func bedGain(for bed: AVAudioPCMBuffer, in pack: DubPack) -> Float {
        let stretches = pack.lines.map { $0.startTime..<max($0.startTime, $0.endTime) }
        return bedGain(bed: bedLevel(of: bed, under: stretches), dialogue: dialogueLevel(of: pack))
    }
}
