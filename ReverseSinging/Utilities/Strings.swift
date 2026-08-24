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
        static let uiPreferenceTitle = NSLocalizedString("onboarding.uiPreference.title", comment: "UI preference title")
        static let uiPreferenceMessage = NSLocalizedString("onboarding.uiPreference.message", comment: "UI preference message")
        static let buttonContinue = NSLocalizedString("onboarding.button.continue", comment: "Continue button")
        static let buttonOpenSettings = NSLocalizedString("onboarding.button.openSettings", comment: "Open settings button")
        static let buttonLetsRecord = NSLocalizedString("onboarding.button.letsRecord", comment: "Let's record button")
        static let buttonContinueLowercase = NSLocalizedString("onboarding.button.continueLowercase", comment: "Continue button lowercase")
    }

    // MARK: - Main View
    enum Main {
        // Editor chrome
        enum Section {
            static let transport = NSLocalizedString("main.section.transport", comment: "Transport controls section label")
            static let monitor = NSLocalizedString("main.section.monitor", comment: "Monitor panel section label")
            static let hint = NSLocalizedString("main.section.hint", comment: "Hint strip label")
        }

        /// The two games, offered side by side on the main screen.
        enum Mode {
            static let section = NSLocalizedString("main.mode.section", comment: "Game mode section label")
            static let reverseTitle = NSLocalizedString("main.mode.reverse.title", comment: "Reverse singing game mode")
            static let reverseSubtitle = NSLocalizedString("main.mode.reverse.subtitle", comment: "Reverse singing game description")
            static let dubTitle = NSLocalizedString("main.mode.dub.title", comment: "Movie scene dub game mode")
            static let dubSubtitle = NSLocalizedString("main.mode.dub.subtitle", comment: "Movie scene dub game description")
        }

        /// Transport state, shown uppercase in the monitor strip.
        enum State {
            static let idle = NSLocalizedString("main.state.idle", comment: "Transport idle")
            static let recording = NSLocalizedString("main.state.recording", comment: "Transport recording")
            static let playing = NSLocalizedString("main.state.playing", comment: "Transport playing")
            static let processing = NSLocalizedString("main.state.processing", comment: "Transport processing")
            static let error = NSLocalizedString("main.state.error", comment: "Transport error")
            static let countingIn = NSLocalizedString("main.state.countingIn", comment: "Transport counting in before recording")
        }

        // Buttons
        static let back = NSLocalizedString("main.button.back", comment: "Back to the game menu")
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
        static let archiveTitle = NSLocalizedString("session.archiveTitle", comment: "Archive / saved sessions")
    }

    // MARK: - Errors
    enum Error {
        static let microphonePermissionRequired = NSLocalizedString("error.microphonePermissionRequired", comment: "Microphone permission required error")
        static let cannotStartRecording = NSLocalizedString("error.cannotStartRecording", comment: "Cannot start recording error")
        static let noRecordingInProgress = NSLocalizedString("error.noRecordingInProgress", comment: "No recording in progress error")
        static let failedToStopRecording = NSLocalizedString("error.failedToStopRecording", comment: "Failed to stop recording error")
        static let failedToProcessRecording = NSLocalizedString("error.failedToProcessRecording", comment: "Failed to process recording error")
    }

    // MARK: - Settings
    enum Settings {
        static let title = NSLocalizedString("settings.title", comment: "Settings title")
        static let subtitle = NSLocalizedString("settings.subtitle", comment: "Settings subtitle")
        static let appearance = NSLocalizedString("settings.appearance", comment: "Appearance section")
        static let interface = NSLocalizedString("settings.interface", comment: "Interface section")
        static let preferences = NSLocalizedString("settings.preferences", comment: "Preferences section")
        static let about = NSLocalizedString("settings.about", comment: "About section")

        // Theme descriptions
        static let themeSystemDesc = NSLocalizedString("settings.theme.system.desc", comment: "System theme description")
        static let themeLightDesc = NSLocalizedString("settings.theme.light.desc", comment: "Light theme description")
        static let themeDarkDesc = NSLocalizedString("settings.theme.dark.desc", comment: "Dark theme description")

        // Haptic feedback
        static let hapticFeedback = NSLocalizedString("settings.hapticFeedback", comment: "Haptic feedback label")
        static let hapticFeedbackDesc = NSLocalizedString("settings.hapticFeedback.desc", comment: "Haptic feedback description")

        // Sound
        static let soundEffects = NSLocalizedString("settings.soundEffects", comment: "Sound effects label")
        static let soundEffectsDesc = NSLocalizedString("settings.soundEffects.desc", comment: "Sound effects description")

        // Headphone monitoring
        static let headphoneMonitor = NSLocalizedString("settings.headphoneMonitor", comment: "Play the original in headphones label")
        static let headphoneMonitorDesc = NSLocalizedString("settings.headphoneMonitor.desc", comment: "Play the original in headphones description")
        static let headphoneMonitorUnavailable = NSLocalizedString("settings.headphoneMonitor.unavailable", comment: "Shown when no headphones are connected")

        // About
        static let privacyPolicy = NSLocalizedString("settings.privacyPolicy", comment: "Privacy policy label")
        static let builtInSwitzerland = NSLocalizedString("settings.builtInSwitzerland", comment: "Built in Switzerland label")
        static let builtInSwitzerlandDesc = NSLocalizedString("settings.builtInSwitzerland.desc", comment: "Built in Switzerland description")
    }

    // MARK: - Dub Mode
    enum Dub {
        static let title = NSLocalizedString("dub.title", comment: "Dub library title")
        static let subtitle = NSLocalizedString("dub.subtitle", comment: "Dub library subtitle")
        static let unknownAuthor = NSLocalizedString("dub.unknownAuthor", comment: "Fallback pack author")
        static let importPack = NSLocalizedString("dub.importPack", comment: "Import pack button")
        static let importing = NSLocalizedString("dub.importing", comment: "Importing progress message")
        static let convertingVideo = NSLocalizedString("dub.convertingVideo", comment: "Import stage: converting the scene video")
        static let importReading = NSLocalizedString("dub.importReading", comment: "Import stage: reading the pack")
        static let delete = NSLocalizedString("dub.delete", comment: "Delete pack action")
        static let done = NSLocalizedString("dub.done", comment: "Done button")
        static let close = NSLocalizedString("dub.close", comment: "Close button")

        // Library empty state
        static let emptyTitle = NSLocalizedString("dub.empty.title", comment: "Empty library title")
        static let emptyMessage = NSLocalizedString("dub.empty.message", comment: "Empty library message")

        // Pack detail
        static let playOriginal = NSLocalizedString("dub.playOriginal", comment: "Play original scene")
        static let playMyDub = NSLocalizedString("dub.playMyDub", comment: "Play the user's dub")
        static let record = NSLocalizedString("dub.record", comment: "Start recording lines")
        static let continueRecording = NSLocalizedString("dub.continueRecording", comment: "Resume recording lines")
        static let export = NSLocalizedString("dub.export", comment: "Export video button")
        static let lines = NSLocalizedString("dub.lines", comment: "Lines section header")
        static let packsSection = NSLocalizedString("dub.packsSection", comment: "Packs section label")
        static let slateLines = NSLocalizedString("dub.slate.lines", comment: "Slate field: lines dubbed")
        static let slateDuration = NSLocalizedString("dub.slate.duration", comment: "Slate field: scene duration")
        static let slateCast = NSLocalizedString("dub.slate.cast", comment: "Slate field: number of characters")
        static let linesRecorded = NSLocalizedString("dub.linesRecorded", comment: "N of M lines recorded — takes two integers")

        // Recording
        static let listen = NSLocalizedString("dub.listen", comment: "Listen to reference line")
        static let stop = NSLocalizedString("dub.stop", comment: "Stop button")
        static let recordTake = NSLocalizedString("dub.recordTake", comment: "Record your take")
        static let reRecord = NSLocalizedString("dub.reRecord", comment: "Re-record this line")
        static let next = NSLocalizedString("dub.next", comment: "Next line")
        static let previous = NSLocalizedString("dub.previous", comment: "Previous line")
        static let lineProgress = NSLocalizedString("dub.lineProgress", comment: "Line N of M — takes two integers")
        static let recordingHint = NSLocalizedString("dub.recordingHint", comment: "Hint shown while recording a line")
        static let listenHint = NSLocalizedString("dub.listenHint", comment: "Hint shown before recording a line")
        static let playTake = NSLocalizedString("dub.playTake", comment: "Play the user's take of one line")
        static let speakerAccessibility = NSLocalizedString("dub.speakerAccessibility", comment: "Accessibility label naming who speaks the line")
        static let cast = NSLocalizedString("dub.cast", comment: "Cast list header")
        static let referenceTrack = NSLocalizedString("dub.referenceTrack", comment: "Waveform label: the pack's own audio")
        static let yourTake = NSLocalizedString("dub.yourTake", comment: "Waveform label: the user's recording")
        static let loadingScene = NSLocalizedString("dub.loadingScene", comment: "Shown while a scene's audio loads")

        // Playback
        static let original = NSLocalizedString("dub.original", comment: "Original audio mode")
        static let myDub = NSLocalizedString("dub.myDub", comment: "User dub audio mode")
        static let noTakesYet = NSLocalizedString("dub.noTakesYet", comment: "Shown when nothing has been recorded")

        // Export
        static let exporting = NSLocalizedString("dub.exporting", comment: "Export in progress")
        static let exportMixing = NSLocalizedString("dub.export.mixing", comment: "Export stage: mixing audio")
        static let exportRendering = NSLocalizedString("dub.export.rendering", comment: "Export stage: rendering video")
        static let exportReady = NSLocalizedString("dub.export.ready", comment: "Export finished")
        static let shareDub = NSLocalizedString("dub.shareDub", comment: "Share sheet label")

        enum Error {
            static let missingPackInfo = NSLocalizedString("dub.error.missingPackInfo", comment: "Pack info file missing")
            static let noLines = NSLocalizedString("dub.error.noLines", comment: "No usable lines in pack")
            static let missingAsset = NSLocalizedString("dub.error.missingAsset", comment: "Referenced asset missing — takes a filename")
            static let notAFolder = NSLocalizedString("dub.error.notAFolder", comment: "Selected item is not a pack")
            static let unreadableArchive = NSLocalizedString("dub.error.unreadableArchive", comment: "Zip could not be read — takes an error message")
            static let nothingRecorded = NSLocalizedString("dub.error.nothingRecorded", comment: "Export attempted with no takes")
            static let exportFailed = NSLocalizedString("dub.error.exportFailed", comment: "Export failed — takes an error message")
        }
    }

    // MARK: - Dub Content Gate
    enum DubGate {
        static let close = NSLocalizedString("dubGate.close", comment: "Close the dubbing gate modal")

        // Step 1 - do you have the movies?
        static let askTitle = NSLocalizedString("dubGate.ask.title", comment: "Dub gate question title")
        static let askMessage = NSLocalizedString("dubGate.ask.message", comment: "Dub gate question message")
        static let askConfirm = NSLocalizedString("dubGate.ask.confirm", comment: "User already has the movies")
        static let askNeedDownload = NSLocalizedString("dubGate.ask.needDownload", comment: "User still needs to download the movies")

        // Step 2 - where to download
        static let downloadTitle = NSLocalizedString("dubGate.download.title", comment: "Download step title")
        static let downloadMessage = NSLocalizedString("dubGate.download.message", comment: "Download step message")
        static let downloadOpen = NSLocalizedString("dubGate.download.open", comment: "Open the example site, %@ is the site name")
        static let downloadBack = NSLocalizedString("dubGate.download.back", comment: "Back to the previous step")

        // Disclaimers
        static let disclaimerNotAffiliated = NSLocalizedString("dubGate.disclaimer.notAffiliated", comment: "No affiliation disclaimer, %@ is the site host")
        static let disclaimerResponsibility = NSLocalizedString("dubGate.disclaimer.responsibility", comment: "Copyright responsibility disclaimer")
    }
}
