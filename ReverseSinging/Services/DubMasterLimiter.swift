//
//  DubMasterLimiter.swift
//  ReverseSinging
//
//  A brickwall on the way out, so a summed mix can't clip
//

import AVFoundation
import AudioToolbox

/// Puts a peak limiter between an engine's main mixer and its output.
///
/// Needed since overlapping lines started being summed rather than one of them being dropped:
/// two takes recorded hot, on top of each other and over a backing track, add up past full
/// scale, and past full scale the encoder just squares off the tops. A limiter is what a
/// dialogue stem would have in any real mix.
///
/// Installed on both the export mixer and the in-app scene player, so the preview and the file
/// behave the same way.
nonisolated enum DubMasterLimiter {

    /// Fast enough to catch a plosive, slow enough that speech doesn't pump. Below about a
    /// millisecond a limiter starts distorting low frequencies rather than controlling them.
    private static let attackTime: AudioUnitParameterValue = 0.003
    private static let releaseTime: AudioUnitParameterValue = 0.030

    /// - Parameter engine: must not be running. Rewiring the output while it renders is not
    ///   something to rely on.
    /// - Returns: the limiter, or nil when the audio unit is unavailable — in which case the
    ///   graph is left exactly as it was and the mix simply runs unlimited.
    @discardableResult
    static func install(in engine: AVAudioEngine) -> AVAudioUnitEffect? {
        let description = AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: kAudioUnitSubType_PeakLimiter,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )

        // Confirm the unit exists before `AVAudioUnitEffect` traps on a description it
        // cannot instantiate.
        var query = description
        guard AudioComponentFindNext(nil, &query) != nil else { return nil }

        let limiter = AVAudioUnitEffect(audioComponentDescription: description)
        engine.attach(limiter)

        // Touching `mainMixerNode` is what creates it and wires it to the output; the
        // rewiring below only makes sense once that has happened.
        let mixer = engine.mainMixerNode
        engine.disconnectNodeInput(engine.outputNode)

        // Formats are left to the engine: this sits between two nodes whose formats it has
        // already decided, and the export re-decides them again when manual rendering is
        // enabled.
        engine.connect(mixer, to: limiter, format: nil)
        engine.connect(limiter, to: engine.outputNode, format: nil)

        set(kLimiterParam_AttackTime, to: attackTime, on: limiter)
        set(kLimiterParam_DecayTime, to: releaseTime, on: limiter)
        // Unity in: the ceiling is fixed at full scale, so any pre-gain here would be gain
        // staging by another name.
        set(kLimiterParam_PreGain, to: 0, on: limiter)

        return limiter
    }

    private static func set(
        _ parameter: AudioUnitParameterID,
        to value: AudioUnitParameterValue,
        on limiter: AVAudioUnitEffect
    ) {
        AudioUnitSetParameter(limiter.audioUnit, parameter, kAudioUnitScope_Global, 0, value, 0)
    }
}
