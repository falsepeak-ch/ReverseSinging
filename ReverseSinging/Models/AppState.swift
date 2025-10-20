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

    mutating func startNewSession() {
        currentSession = AudioSession()
    }

    mutating func saveCurrentSession() {
        guard let session = currentSession, !session.recordings.isEmpty else {
            currentSession = nil
            return
        }
        savedSessions.insert(session, at: 0)
        currentSession = nil
    }

    mutating func deleteSession(_ session: AudioSession) {
        savedSessions.removeAll { $0.id == session.id }
    }
}
