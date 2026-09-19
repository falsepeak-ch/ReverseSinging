//
//  DubPackInstallProgress.swift
//  DubPackKit
//

/// How far an install has got, so a multi-minute video conversion can say what it is doing
/// rather than showing a bar that looks stuck.
public struct DubPackInstallProgress: Sendable, Hashable {

    public enum Stage: String, Sendable, Hashable, CaseIterable {
        /// Unpacking the archive, or copying the folder, into the library.
        case copying
        /// Converting a Theora scene to H.264. Usually by far the longest stage.
        case convertingVideo = "converting_video"
        /// Reading every entry and measuring every reference recording.
        case reading
    }

    public let stage: Stage
    /// How far through `stage`, from 0 to 1.
    public let fraction: Double

    public init(stage: Stage, fraction: Double) {
        self.stage = stage
        self.fraction = min(1, max(0, fraction))
    }
}
