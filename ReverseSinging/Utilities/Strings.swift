//
//  Strings.swift
//  ReverseSinging
//
//  Type-safe localized strings
//

import Foundation

enum Strings {

    // MARK: - Onboarding
    enum Onboarding {
        static let welcomeTitle = NSLocalizedString("onboarding.welcome.title", comment: "Welcome screen title")
        static let welcomeMessage = NSLocalizedString("onboarding.welcome.message", comment: "Welcome screen message")
        static let howItWorksTitle = NSLocalizedString("onboarding.howItWorks.title", comment: "How it works title")
        static let howItWorksMessage = NSLocalizedString("onboarding.howItWorks.message", comment: "How it works message")
        static let buttonContinue = NSLocalizedString("onboarding.button.continue", comment: "Continue button")
        static let buttonOpenSettings = NSLocalizedString("onboarding.button.openSettings", comment: "Open settings button")
        static let buttonLetsRecord = NSLocalizedString("onboarding.button.letsRecord", comment: "Let's record button")
        static let buttonContinueLowercase = NSLocalizedString("onboarding.button.continueLowercase", comment: "Continue button lowercase")
    }

    // MARK: - Main View
    enum Main {
        // Buttons
        static let stopRecording = NSLocalizedString("main.button.stopRecording", comment: "Stop recording button")
        static let recordAudio = NSLocalizedString("main.button.recordAudio", comment: "Record audio button")
        static let recordAttempt = NSLocalizedString("main.button.recordAttempt", comment: "Record attempt button")
        static let reRecord = NSLocalizedString("main.button.reRecord", comment: "Re-record button")
        static let newSession = NSLocalizedString("main.button.newSession", comment: "New session button")

        // Alerts
        enum Alert {
            static let microphoneRequiredTitle = NSLocalizedString("main.alert.microphoneRequired.title", comment: "Microphone required alert title")
            static let microphoneRequiredMessage = NSLocalizedString("main.alert.microphoneRequired.message", comment: "Microphone required alert message")
            static let settings = NSLocalizedString("main.alert.settings", comment: "Settings button")
            static let cancel = NSLocalizedString("main.alert.cancel", comment: "Cancel button")
            static let errorTitle = NSLocalizedString("main.alert.error.title", comment: "Error alert title")
            static let ok = NSLocalizedString("main.alert.ok", comment: "OK button")
            static let startNewSessionTitle = NSLocalizedString("main.alert.startNewSession.title", comment: "Start new session alert title")
            static let startNewSessionMessage = NSLocalizedString("main.alert.startNewSession.message", comment: "Start new session alert message")
            static let startNewSessionButton = NSLocalizedString("main.alert.startNewSession.button", comment: "Start new session button")
        }

        // Empty State
        enum EmptyState {
            static let title = NSLocalizedString("main.emptyState.title", comment: "Empty state title")
            static let message = NSLocalizedString("main.emptyState.message", comment: "Empty state message")
            static let button = NSLocalizedString("main.emptyState.button", comment: "Empty state button")
        }

        // Processing & Success
        static let processingReversingAudio = NSLocalizedString("main.processing.reversingAudio", comment: "Reversing audio message")
        static let successSessionSaved = NSLocalizedString("main.success.sessionSaved", comment: "Session saved message")

        // Tips
        enum Tip {
            static let tapRecordToBegin = NSLocalizedString("main.tip.tapRecordToBegin", comment: "Tap record to begin tip")
            static let recordSingingAttempt = NSLocalizedString("main.tip.recordSingingAttempt", comment: "Record singing attempt tip")
            static let recordSongToReverse = NSLocalizedString("main.tip.recordSongToReverse", comment: "Record song to reverse tip")
            static let tapPlayToSwitch = NSLocalizedString("main.tip.tapPlayToSwitch", comment: "Tap play to switch tip")
            static let reRecordOrNewSession = NSLocalizedString("main.tip.reRecordOrNewSession", comment: "Re-record or new session tip")
            static let listenAndRecord = NSLocalizedString("main.tip.listenAndRecord", comment: "Listen and record tip")
            static let processingAudio = NSLocalizedString("main.tip.processingAudio", comment: "Processing audio tip")
            static let tapRecordAudio = NSLocalizedString("main.tip.tapRecordAudio", comment: "Tap record audio tip")
        }
    }

    // MARK: - Comparison View
    enum Comparison {
        static let title = NSLocalizedString("comparison.title", comment: "Comparison view title")
        static let buttonClose = NSLocalizedString("comparison.button.close", comment: "Close button")
        static let labelOriginal = NSLocalizedString("comparison.label.original", comment: "Original label")
        static let labelYourTry = NSLocalizedString("comparison.label.yourTry", comment: "Your try label")
        static let buttonPlayOriginal = NSLocalizedString("comparison.button.playOriginal", comment: "Play original button")
        static let buttonPlayYourTry = NSLocalizedString("comparison.button.playYourTry", comment: "Play your try button")
        static let buttonStop = NSLocalizedString("comparison.button.stop", comment: "Stop button")
        static let buttonSaveSession = NSLocalizedString("comparison.button.saveSession", comment: "Save session button")
        static let buttonTryAgain = NSLocalizedString("comparison.button.tryAgain", comment: "Try again button")

        // Score Messages
        enum Score {
            static let amazing = NSLocalizedString("comparison.score.amazing", comment: "Amazing score message")
            static let great = NSLocalizedString("comparison.score.great", comment: "Great score message")
            static let good = NSLocalizedString("comparison.score.good", comment: "Good score message")
            static let keepPracticing = NSLocalizedString("comparison.score.keepPracticing", comment: "Keep practicing message")
        }
    }

    // MARK: - Session List
    enum SessionList {
        static let title = NSLocalizedString("sessionList.title", comment: "Session list title")

        enum Empty {
            static let title = NSLocalizedString("sessionList.empty.title", comment: "Empty session list title")
            static let message = NSLocalizedString("sessionList.empty.message", comment: "Empty session list message")
        }
    }

    // MARK: - Recording Types
    enum RecordingType {
        static let original = NSLocalizedString("recordingType.original", comment: "Original recording type")
        static let reversed = NSLocalizedString("recordingType.reversed", comment: "Reversed recording type")
        static let attempt = NSLocalizedString("recordingType.attempt", comment: "Attempt recording type")
        static let reversedAttempt = NSLocalizedString("recordingType.reversedAttempt", comment: "Reversed attempt recording type")
        static let imported = NSLocalizedString("recordingType.imported", comment: "Imported recording type")
    }

    // MARK: - Timer Card
    enum TimerCard {
        static let deviceMicrophone = NSLocalizedString("timerCard.deviceMicrophone", comment: "Device microphone label")
        static let mins = NSLocalizedString("timerCard.mins", comment: "Minutes label")
        static let secs = NSLocalizedString("timerCard.secs", comment: "Seconds label")
        static let playAudio = NSLocalizedString("timerCard.playAudio", comment: "Play audio label")
        static let audioControls = NSLocalizedString("timerCard.audioControls", comment: "Audio controls label")
        static let loop = NSLocalizedString("timerCard.loop", comment: "Loop label")
        static let speed = NSLocalizedString("timerCard.speed", comment: "Speed label")
        static let pitch = NSLocalizedString("timerCard.pitch", comment: "Pitch label")
        static let semitones = NSLocalizedString("timerCard.semitones", comment: "Semitones label")
    }

    // MARK: - Score Card
    enum ScoreCard {
        static let title = NSLocalizedString("scoreCard.title", comment: "Score card title")

        enum Grade {
            static let perfectMatch = NSLocalizedString("scoreCard.grade.perfectMatch", comment: "Perfect match grade")
            static let excellent = NSLocalizedString("scoreCard.grade.excellent", comment: "Excellent grade")
            static let greatJob = NSLocalizedString("scoreCard.grade.greatJob", comment: "Great job grade")
            static let veryGood = NSLocalizedString("scoreCard.grade.veryGood", comment: "Very good grade")
            static let goodEffort = NSLocalizedString("scoreCard.grade.goodEffort", comment: "Good effort grade")
            static let niceTry = NSLocalizedString("scoreCard.grade.niceTry", comment: "Nice try grade")
            static let keepPracticing = NSLocalizedString("scoreCard.grade.keepPracticing", comment: "Keep practicing grade")
            static let tryAgain = NSLocalizedString("scoreCard.grade.tryAgain", comment: "Try again grade")
        }
    }

    // MARK: - Processing
    enum Processing {
        static let reversingAudio = NSLocalizedString("processing.reversingAudio", comment: "Reversing audio message")
        static let generic = NSLocalizedString("processing.generic", comment: "Generic processing message")
    }

    // MARK: - Recording Indicator
    enum Recording {
        static let indicator = NSLocalizedString("recording.indicator", comment: "Recording indicator")
    }

    // MARK: - Success
    enum Success {
        static let sessionSaved = NSLocalizedString("success.sessionSaved", comment: "Session saved message")
    }

    // MARK: - Session
    enum Session {
        static let defaultName = NSLocalizedString("session.defaultName", comment: "Default session name")
    }

    // MARK: - Errors
    enum Error {
        static let microphonePermissionRequired = NSLocalizedString("error.microphonePermissionRequired", comment: "Microphone permission required error")
        static let cannotStartRecording = NSLocalizedString("error.cannotStartRecording", comment: "Cannot start recording error")
        static let noRecordingInProgress = NSLocalizedString("error.noRecordingInProgress", comment: "No recording in progress error")
        static let failedToStopRecording = NSLocalizedString("error.failedToStopRecording", comment: "Failed to stop recording error")
        static let failedToProcessRecording = NSLocalizedString("error.failedToProcessRecording", comment: "Failed to process recording error")
    }
}
