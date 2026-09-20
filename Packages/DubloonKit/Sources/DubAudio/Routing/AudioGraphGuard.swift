//
//  AudioGraphGuard.swift
//  DubAudio
//

internal import DubObjCSupport
public import Foundation

/// Turns the Objective-C exceptions AVAudioEngine raises into thrown errors.
///
/// `AVAudioEngine.connect(_:to:format:)` raises when the mixer cannot take the format it is
/// handed, which it cannot whenever the audio session is not active and the output has no
/// route, and `AVAudioPlayerNode.play(at:)` raises when the node has not yet seen a render
/// cycle. Neither is a Swift error, so neither could be caught, and each was a crash for every
/// user whose audio session another app happened to hold. Wrapped here, they are failures the
/// caller can show and recover from.
public enum AudioGraphGuard {

    /// An Objective-C exception, caught.
    public struct RaisedException: Error, CustomStringConvertible, Sendable {
        /// The exception's name, such as `com.apple.coreaudio.avfaudio`.
        public let name: String
        /// The exception's reason, such as `error -10868`.
        public let reason: String

        public var description: String { "\(name): \(reason)" }
    }

    /// Runs `body`. An exception raised inside it is thrown instead of ending the process.
    public static func attempt(_ body: () -> Void) throws(RaisedException) {
        guard let error = DubExceptionCatcher.catchException(in: body) else { return }
        let nsError = error as NSError
        throw RaisedException(
            name: nsError.userInfo[DubObjCExceptionNameKey] as? String ?? "NSException",
            reason: nsError.localizedDescription
        )
    }

    /// `attempt`, for callers that only need to know whether it worked.
    @discardableResult
    public static func succeeds(_ body: () -> Void) -> Bool {
        (try? attempt(body)) != nil
    }
}
