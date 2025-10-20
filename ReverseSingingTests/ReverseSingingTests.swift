//
//  ReverseSingingTests.swift
//  ReverseSingingTests
//
//  Comprehensive unit tests for Reverse Singing app
//

import Testing
import Foundation
@testable import ReverseSinging

// MARK: - Model Tests

@Suite("Recording Model Tests")
struct RecordingTests {

    @Test func recordingInitialization() {
        let url = URL(fileURLWithPath: "/tmp/test.m4a")
        let recording = Recording(url: url, duration: 120.5, type: .original)

        #expect(recording.url == url)
        #expect(recording.duration == 120.5)
        #expect(recording.type == .original)
        #expect(recording.id != UUID())
    }

    @Test func formattedDuration() {
        let url = URL(fileURLWithPath: "/tmp/test.m4a")

        let shortRecording = Recording(url: url, duration: 45.0, type: .original)
        #expect(shortRecording.formattedDuration == "0:45")

        let longRecording = Recording(url: url, duration: 125.0, type: .reversed)
        #expect(longRecording.formattedDuration == "2:05")

        let veryLongRecording = Recording(url: url, duration: 3665.0, type: .attempt)
        #expect(veryLongRecording.formattedDuration == "61:05")
    }

    @Test func recordingTypes() {
        let types: [Recording.RecordingType] = [.original, .reversed, .attempt, .imported]
        let expectedNames = ["Original", "Reversed", "Attempt", "Imported"]

        for (type, expectedName) in zip(types, expectedNames) {
            #expect(type.rawValue == expectedName)
        }
    }
}

@Suite("AudioSession Model Tests")
struct AudioSessionTests {

    @Test func sessionInitialization() {
        let session = AudioSession()

        #expect(session.recordings.isEmpty)
        #expect(session.name == "Session")
        #expect(session.id != UUID())
    }

    @Test func customSessionName() {
        let session = AudioSession(name: "My Test Session")
        #expect(session.name == "My Test Session")
    }

    @Test func addRecording() {
        var session = AudioSession()
        let url = URL(fileURLWithPath: "/tmp/test.m4a")
        let recording = Recording(url: url, duration: 60.0, type: .original)

        session.addRecording(recording)

        #expect(session.recordings.count == 1)
        #expect(session.recordings.first?.id == recording.id)
    }

    @Test func removeRecording() {
        var session = AudioSession()
        let url = URL(fileURLWithPath: "/tmp/test.m4a")
        let recording1 = Recording(url: url, duration: 60.0, type: .original)
        let recording2 = Recording(url: url, duration: 60.0, type: .reversed)

        session.addRecording(recording1)
        session.addRecording(recording2)
        #expect(session.recordings.count == 2)

        session.removeRecording(recording1)
        #expect(session.recordings.count == 1)
        #expect(session.recordings.first?.id == recording2.id)
    }

    @Test func recordingAccessors() {
        var session = AudioSession()
        let url = URL(fileURLWithPath: "/tmp/test.m4a")

        let original = Recording(url: url, duration: 60.0, type: .original)
        let reversed = Recording(url: url, duration: 60.0, type: .reversed)
        let attempt = Recording(url: url, duration: 60.0, type: .attempt)

        session.addRecording(original)
        session.addRecording(reversed)
        session.addRecording(attempt)

        #expect(session.originalRecording?.id == original.id)
        #expect(session.reversedRecording?.id == reversed.id)
        #expect(session.attemptRecording?.id == attempt.id)
    }

    @Test func importedRecordingIsOriginal() {
        var session = AudioSession()
        let url = URL(fileURLWithPath: "/tmp/test.m4a")
        let imported = Recording(url: url, duration: 60.0, type: .imported)

        session.addRecording(imported)

        #expect(session.originalRecording?.id == imported.id)
    }
}

@Suite("AppState Model Tests")
struct AppStateTests {

    @Test func defaultState() {
        let state = AppState()

        #expect(state.savedSessions.isEmpty)
        #expect(state.currentSession == nil)
        #expect(state.hasCompletedOnboarding == false)
        #expect(state.playbackSpeed == 1.0)
        #expect(state.isLooping == false)
    }

    @Test func startNewSession() {
        var state = AppState()
        #expect(state.currentSession == nil)

        state.startNewSession()

        #expect(state.currentSession != nil)
        #expect(state.currentSession?.recordings.isEmpty == true)
    }

    @Test func saveCurrentSession() {
        var state = AppState()
        state.startNewSession()

        let url = URL(fileURLWithPath: "/tmp/test.m4a")
        let recording = Recording(url: url, duration: 60.0, type: .original)
        state.currentSession?.addRecording(recording)

        state.saveCurrentSession()

        #expect(state.savedSessions.count == 1)
        #expect(state.currentSession == nil)
    }

    @Test func dontSaveEmptySession() {
        var state = AppState()
        state.startNewSession()

        state.saveCurrentSession()

        #expect(state.savedSessions.isEmpty)
        #expect(state.currentSession == nil)
    }

    @Test func deleteSession() {
        var state = AppState()
        let session1 = AudioSession(name: "Session 1")
        let session2 = AudioSession(name: "Session 2")

        state.savedSessions = [session1, session2]

        state.deleteSession(session1)

        #expect(state.savedSessions.count == 1)
        #expect(state.savedSessions.first?.id == session2.id)
    }

    @Test func recordingStateEnum() {
        let idle: RecordingState = .idle
        let recording: RecordingState = .recording
        let playing: RecordingState = .playing
        let reversing: RecordingState = .reversing
        let error: RecordingState = .error("Test error")

        // Just verify they compile and can be assigned
        #expect(idle != recording)
        #expect(playing != reversing)

        if case .error(let message) = error {
            #expect(message == "Test error")
        }
    }
}

// MARK: - Service Tests

@Suite("AudioFileManager Tests")
struct AudioFileManagerTests {

    @Test func sharedInstance() {
        let manager1 = AudioFileManager.shared
        let manager2 = AudioFileManager.shared

        #expect(manager1 === manager2)
    }

    @Test func createTemporaryURL() {
        let manager = AudioFileManager.shared

        let url1 = manager.createTemporaryAudioURL()
        let url2 = manager.createTemporaryAudioURL()

        #expect(url1.pathExtension == "m4a")
        #expect(url2.pathExtension == "m4a")
        #expect(url1 != url2) // Should be unique
    }

    @Test func recordingsDirectory() {
        let manager = AudioFileManager.shared
        let recordingsDir = manager.recordingsDirectory()

        #expect(recordingsDir.lastPathComponent == "Recordings")
        #expect(recordingsDir.path().contains("Documents"))
    }
}

@Suite("HapticManager Tests")
struct HapticManagerTests {

    @Test func sharedInstance() {
        let manager1 = HapticManager.shared
        let manager2 = HapticManager.shared

        #expect(manager1 === manager2)
    }

    @Test func hapticMethodsExist() {
        let manager = HapticManager.shared

        // Just verify methods exist and don't crash
        manager.light()
        manager.medium()
        manager.heavy()
        manager.soft()
        manager.rigid()
        manager.success()
        manager.warning()
        manager.error()
        manager.selection()
    }
}

// MARK: - ViewModel Tests

@Suite("AudioViewModel Tests") @MainActor
struct AudioViewModelTests {

    @Test func initialization() async {
        let viewModel = AudioViewModel()

        #expect(viewModel.appState.savedSessions.isEmpty)
        #expect(viewModel.appState.currentSession == nil)
        #expect(!viewModel.isReversing)
        #expect(!viewModel.showSessionList)
    }

    @Test func startNewSession() async {
        let viewModel = AudioViewModel()

        viewModel.startNewSession()

        #expect(viewModel.appState.currentSession != nil)
        #expect(viewModel.appState.currentSession?.recordings.isEmpty == true)
    }

    @Test func saveSession() async {
        let viewModel = AudioViewModel()
        viewModel.startNewSession()

        // Add a dummy recording
        let url = URL(fileURLWithPath: "/tmp/test.m4a")
        let recording = Recording(url: url, duration: 60.0, type: .original)
        viewModel.appState.currentSession?.addRecording(recording)

        viewModel.saveSession()

        #expect(viewModel.appState.savedSessions.count == 1)
        #expect(viewModel.appState.currentSession == nil)
    }

    @Test func deleteSession() async {
        let viewModel = AudioViewModel()

        let url = URL(fileURLWithPath: "/tmp/test.m4a")
        let recording = Recording(url: url, duration: 60.0, type: .original)

        var session = AudioSession(name: "Test Session")
        session.addRecording(recording)

        viewModel.appState.savedSessions = [session]

        viewModel.deleteSession(session)

        #expect(viewModel.appState.savedSessions.isEmpty)
    }

    @Test func playbackSpeed() async {
        let viewModel = AudioViewModel()

        viewModel.setPlaybackSpeed(0.5)
        #expect(viewModel.appState.playbackSpeed == 0.5)

        viewModel.setPlaybackSpeed(2.0)
        #expect(viewModel.appState.playbackSpeed == 2.0)
    }

    @Test func completeOnboarding() async {
        let viewModel = AudioViewModel()

        #expect(!viewModel.appState.hasCompletedOnboarding)

        viewModel.completeOnboarding()

        #expect(viewModel.appState.hasCompletedOnboarding)
    }
}

// MARK: - Codable Tests

@Suite("Codable Compliance Tests") @MainActor
struct CodableTests {

    @Test func recordingCodable() async throws {
        let url = URL(fileURLWithPath: "/tmp/test.m4a")
        let original = Recording(url: url, duration: 123.45, type: .original)

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Recording.self, from: encoded)

        #expect(decoded.id == original.id)
        #expect(decoded.url == original.url)
        #expect(decoded.duration == original.duration)
        #expect(decoded.type == original.type)
    }

    @Test func audioSessionCodable() async throws {
        var session = AudioSession(name: "Test Session")
        let url = URL(fileURLWithPath: "/tmp/test.m4a")
        let recording = Recording(url: url, duration: 60.0, type: .original)
        session.addRecording(recording)

        let encoded = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(AudioSession.self, from: encoded)

        #expect(decoded.id == session.id)
        #expect(decoded.name == session.name)
        #expect(decoded.recordings.count == 1)
        #expect(decoded.recordings.first?.id == recording.id)
    }

    @Test func recordingTypesCodable() async throws {
        let types: [Recording.RecordingType] = [.original, .reversed, .attempt, .imported]

        for type in types {
            let encoded = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(Recording.RecordingType.self, from: encoded)
            #expect(decoded == type)
        }
    }
}
