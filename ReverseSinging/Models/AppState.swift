//
//  AppState.swift
//  ReverseSinging
//
//  Global app state
//

import Foundation

enum RecordingState: Equatable {
    case idle
    case recording
    case playing
    case reversing
    case error(String)
}

struct AppState {
    var recordingState: RecordingState = .idle
    var currentSession: AudioSession?
    var savedSessions: [AudioSession] = []
    var hasCompletedOnboarding: Bool = false
    var playbackSpeed: Double = 1.0
    var isLooping: Bool = false
    var pitchShift: Float = 0.0  // In cents: -1200 to +1200 (±12 semitones)

    // Game tracking
    var similarityScore: Double? = nil
    var isScoreVisible: Bool = true
    var attemptCount: Int = 0
    var practiceListenCount: Int = 0

    // MARK: - Methods
    // Removed currentGameStep - no longer using step-based flow

    mutating func startNewSession() {
        currentSession = AudioSession()
        similarityScore = nil
        attemptCount = 0
        practiceListenCount = 0
    }

    mutating func saveCurrentSession() {
        guard let session = currentSession, !session.recordings.isEmpty else {
            currentSession = nil
            return
        }
        savedSessions.insert(session, at: 0)
        currentSession = nil
        similarityScore = nil
        attemptCount = 0
        practiceListenCount = 0
    }

    mutating func deleteSession(_ session: AudioSession) {
        savedSessions.removeAll { $0.id == session.id }
    }

    mutating func incrementPracticeListens() {
        practiceListenCount += 1
    }

    mutating func incrementAttemptCount() {
        attemptCount += 1
    }

    mutating func resetAttempt() {
        // Remove attempt and reversed attempt, keep original recordings
        currentSession?.removeRecording(ofType: .attempt)
        currentSession?.removeRecording(ofType: .reversedAttempt)
        similarityScore = nil
        practiceListenCount = 0
    }
}
