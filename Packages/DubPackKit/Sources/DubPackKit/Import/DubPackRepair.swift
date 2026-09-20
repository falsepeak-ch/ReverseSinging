//
//  DubPackRepair.swift
//  DubPackKit
//

public import Foundation

/// Finishes what an earlier install could not: media left in a format the platform does not
/// play, because the conversion was cut short or because the build that installed the pack
/// did not convert that format yet.
///
/// For an installed pack. `DubPackInstaller` does the same work on the way in.
public enum DubPackRepair {

    /// True when the folder holds a Theora scene or Vorbis audio that has not been converted.
    public static func hasPendingConversions(in directory: URL) -> Bool {
        SceneVideoConverter.hasPendingConversion(in: directory)
            || AudioTrackConverter.hasPendingConversion(in: directory)
    }

    /// Converts them, audio first. Returns whatever went wrong; an empty array is a folder that
    /// now plays in full. Blocking work: it runs off the caller's actor.
    @concurrent
    public static func convertPending(
        in directory: URL,
        progress: (@Sendable (DubPackInstallProgress) -> Void)? = nil
    ) async -> [DubPackIssue] {
        let probe = AVFoundationMediaProbe()
        var issues: [DubPackIssue] = []

        let audio = AudioTrackConverter.convertIfNeeded(in: directory) { fraction in
            progress?(.init(stage: .convertingAudio, fraction: fraction))
        }
        issues += audio.issues

        let video = await SceneVideoConverter.convertIfNeeded(in: directory, probe: probe) { fraction in
            progress?(.init(stage: .convertingVideo, fraction: fraction))
        }
        switch video {
        case .nothingToConvert, .converted: break
        case .failed(let file, let failure): issues.append(.videoConversionFailed(file: file, failure: failure))
        case .deferred(let file, let failure): issues.append(.videoConversionDeferred(file: file, failure: failure))
        }
        return issues
    }
}
