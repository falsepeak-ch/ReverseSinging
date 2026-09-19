//
//  ReverseGameViewModelTests.swift
//  ReverseSingingTests
//

import Testing
import Foundation
@testable import ReverseSinging

/// Every test here builds an `ReverseGameViewModel`, and building one loads the whole of `appState`
/// out of `UserDefaults`. So without help these are assertions about the simulator rather
/// than about the view model.
///
/// Two things make them deterministic. `.serialized`, because they share one global
/// `UserDefaults` and a reset in one test would otherwise wipe state another had just written;
/// and `onCleanDevice`, which establishes the empty state each test used to assume. Before
/// this, `saveSession()` would have started counting other tests' sessions, and the onboarding
/// test, now in `AppViewModelTests`, failed on any simulator the app had ever been run on.
@Suite("ReverseGameViewModel Tests", .serialized) @MainActor
struct ReverseGameViewModelTests {

    /// Runs `body` against a device with no saved state, and leaves none behind.
    ///
    /// Resetting afterwards as well as before matters: these keys are the real app's, and a
    /// session left in `UserDefaults` outlives the test run on that simulator.
    private func onCleanDevice(_ body: (ReverseGameViewModel) throws -> Void) rethrows {
        ReverseGameViewModel.resetPersistedStateForTesting()
        defer { ReverseGameViewModel.resetPersistedStateForTesting() }
        try body(ReverseGameViewModel())
    }

    @Test func initialization() async {
        onCleanDevice { viewModel in
            #expect(viewModel.appState.savedSessions.isEmpty)
            #expect(viewModel.appState.currentSession == nil)
            #expect(!viewModel.isReversing)
            #expect(!viewModel.showSessionList)
        }
    }

    @Test func startNewSession() async {
        onCleanDevice { viewModel in
            viewModel.startNewSession()

            #expect(viewModel.appState.currentSession != nil)
            #expect(viewModel.appState.currentSession?.recordings.isEmpty == true)
        }
    }

    @Test func saveSession() async {
        onCleanDevice { viewModel in
            viewModel.startNewSession()

            // Add a dummy recording
            let url = URL(fileURLWithPath: "/tmp/test.m4a")
            let recording = Recording(url: url, duration: 60.0, type: .original)
            viewModel.appState.currentSession?.addRecording(recording)

            viewModel.saveSession()

            #expect(viewModel.appState.savedSessions.count == 1)
            #expect(viewModel.appState.currentSession == nil)
        }
    }

    @Test func deleteSession() async {
        onCleanDevice { viewModel in
            let url = URL(fileURLWithPath: "/tmp/test.m4a")
            let recording = Recording(url: url, duration: 60.0, type: .original)

            var session = AudioSession(name: "Test Session")
            session.addRecording(recording)

            viewModel.appState.savedSessions = [session]

            viewModel.deleteSession(session)

            #expect(viewModel.appState.savedSessions.isEmpty)
        }
    }

    @Test func playbackSpeed() async {
        onCleanDevice { viewModel in
            viewModel.setPlaybackSpeed(0.5)
            #expect(viewModel.appState.playbackSpeed == 0.5)

            viewModel.setPlaybackSpeed(2.0)
            #expect(viewModel.appState.playbackSpeed == 2.0)
        }
    }
}
