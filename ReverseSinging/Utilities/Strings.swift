//
//  Strings.swift
//  ReverseSinging
//
//  Type-safe localized strings
//

import Foundation

nonisolated enum Strings {

    // MARK: - Onboarding
    enum Onboarding {
        static let welcomeTitle = NSLocalizedString("onboarding.welcome.title", comment: "Welcome screen title")
        static let welcomeMessage = NSLocalizedString("onboarding.welcome.message", comment: "Welcome screen message")
        static let howItWorksTitle = NSLocalizedString("onboarding.howItWorks.title", comment: "How it works title")
        static let howItWorksMessage = NSLocalizedString("onboarding.howItWorks.message", comment: "How it works message")
        static let dubTitle = NSLocalizedString("onboarding.dub.title", comment: "Movie scene dub game title")
        static let dubMessage = NSLocalizedString("onboarding.dub.message", comment: "Movie scene dub game message")
        static let uiPreferenceTitle = NSLocalizedString("onboarding.uiPreference.title", comment: "UI preference title")
        static let uiPreferenceMessage = NSLocalizedString("onboarding.uiPreference.message", comment: "UI preference message")
        static let microphoneTitle = NSLocalizedString("onboarding.microphone.title", comment: "Microphone permission title")
        static let microphoneMessage = NSLocalizedString("onboarding.microphone.message", comment: "Microphone permission message")
        static let buttonOpenSettings = NSLocalizedString("onboarding.button.openSettings", comment: "Open settings button")
        static let buttonLetsRecord = NSLocalizedString("onboarding.button.letsRecord", comment: "Let's record button")
        static let buttonContinueLowercase = NSLocalizedString("onboarding.button.continueLowercase", comment: "Continue button lowercase")
        static let buttonMicrophoneContinue = NSLocalizedString("onboarding.button.microphoneContinue", comment: "Primary button on the microphone step. The ask itself is the system prompt it leads to")
        static let buttonContinueWithout = NSLocalizedString("onboarding.button.continueWithout", comment: "Finish onboarding without microphone access")
    }

    // MARK: - Main View
    enum Main {
        // Editor chrome
        enum Section {
            static let transport = NSLocalizedString("main.section.transport", comment: "Transport controls section label")
            static let hint = NSLocalizedString("main.section.hint", comment: "Hint strip label")
            static let session = NSLocalizedString("main.section.session", comment: "Session controls section label")
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
        static let playRecorded = NSLocalizedString("main.button.playRecorded", comment: "Play the recorded audio")
        static let playReverse = NSLocalizedString("main.button.playReverse", comment: "Play the reversed audio")

        /// The simple skin's button subtitles.
        ///
        /// These were English literals inside `MainViewSimple` until 1.3.1, which left every
        /// non-English user looking at an English button stack with a translated hint bar
        /// directly underneath it. The translated keys for the buttons themselves already
        /// existed and were simply never referenced.
        enum Subtitle {
            static let recordingOriginal = NSLocalizedString("main.subtitle.recordingOriginal", comment: "Recording the original audio right now")
            static let recordingAttempt = NSLocalizedString("main.subtitle.recordingAttempt", comment: "Recording the user's attempt right now")
            static let tapToRecord = NSLocalizedString("main.subtitle.tapToRecord", comment: "Nothing recorded yet")
            static let recordAttempt = NSLocalizedString("main.subtitle.recordAttempt", comment: "Prompt to record the singing attempt")
            static let reRecordAttempt = NSLocalizedString("main.subtitle.reRecordAttempt", comment: "Prompt to record the attempt again")
            static let playAttempt = NSLocalizedString("main.subtitle.playAttempt", comment: "Play the user's attempt")
            static let playOriginal = NSLocalizedString("main.subtitle.playOriginal", comment: "Play the original recording")
            static let noRecording = NSLocalizedString("main.subtitle.noRecording", comment: "Nothing recorded yet")
            static let playReversedAttempt = NSLocalizedString("main.subtitle.playReversedAttempt", comment: "Play the reversed attempt")
            static let playReversedOriginal = NSLocalizedString("main.subtitle.playReversedOriginal", comment: "Play the reversed original")
            static let noReversed = NSLocalizedString("main.subtitle.noReversed", comment: "Nothing reversed yet")
        }

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

    // MARK: - Recording Indicator
    enum Recording {
        static let indicator = NSLocalizedString("recording.indicator", comment: "Recording indicator")
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
        static let version = NSLocalizedString("settings.version", comment: "Version and build, takes two strings")
        static let interface = NSLocalizedString("settings.interface", comment: "Interface section")

        /// The two reverse-singing interface skins. Localised because they are shown during
        /// onboarding and in the mode's own options menu, not only in Settings, they were
        /// hardcoded English until 1.3.1 and every non-English user saw them that way.
        enum Mode {
            static let simpleName = NSLocalizedString("uiMode.simple.name", comment: "Simple interface skin")
            static let simpleDescription = NSLocalizedString("uiMode.simple.description", comment: "What the simple skin is")
            static let complexName = NSLocalizedString("uiMode.complex.name", comment: "Complex interface skin")
            static let complexDescription = NSLocalizedString("uiMode.complex.description", comment: "What the complex skin is")
        }
        static let preferences = NSLocalizedString("settings.preferences", comment: "Preferences section")
        static let about = NSLocalizedString("settings.about", comment: "About section")

        // Theme descriptions

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
        static let privacyPolicyDesc = NSLocalizedString("settings.privacyPolicy.desc", comment: "Privacy policy description")
        static let builtInSwitzerland = NSLocalizedString("settings.builtInSwitzerland", comment: "Built in Switzerland label")
        static let builtInSwitzerlandDesc = NSLocalizedString("settings.builtInSwitzerland.desc", comment: "Built in Switzerland description")
    }

    // MARK: - Dub Mode
    // MARK: - Booth Cam

    /// The front camera that films the performer during a take.
    enum Booth {
        /// The slug on the monitor and the panel. Uppercased at the point of use.
        static let slug = NSLocalizedString("booth.slug", comment: "Label on the front-camera monitor")
        static let monitorAccessibility = NSLocalizedString("booth.monitorAccessibility", comment: "Accessibility label for the front-camera monitor")
        static let turnOn = NSLocalizedString("booth.turnOn", comment: "Turn the front camera on")
        static let turnOff = NSLocalizedString("booth.turnOff", comment: "Turn the front camera off")

        // The one-time explanation, shown before the system camera prompt
        static let primerTitle = NSLocalizedString("booth.primer.title", comment: "Booth Cam explanation title")
        static let primerMessage = NSLocalizedString("booth.primer.message", comment: "Booth Cam explanation body")
        static let primerConfirm = NSLocalizedString("booth.primer.confirm", comment: "Turn Booth Cam on")
        static let primerDecline = NSLocalizedString("booth.primer.decline", comment: "Carry on dubbing without the camera")
        static let primerSystemPrompt = NSLocalizedString("booth.primer.systemPrompt", comment: "Warns that the iOS camera prompt comes next")
        static let factOnDevice = NSLocalizedString("booth.fact.onDevice", comment: "Where booth footage is kept")
        static let factNothingLeaves = NSLocalizedString("booth.fact.nothingLeaves", comment: "Nothing is shared until an export")
        static let factReversible = NSLocalizedString("booth.fact.reversible", comment: "The camera can be switched off at any time")

        // Settings
        static let settingsSection = NSLocalizedString("booth.settings.section", comment: "Booth Cam settings section header")
        static let settingsTitle = NSLocalizedString("booth.settings.title", comment: "Booth Cam toggle label")
        static let settingsDesc = NSLocalizedString("booth.settings.desc", comment: "Booth Cam toggle description")
        static let settingsDenied = NSLocalizedString("booth.settings.denied", comment: "Shown when camera access was refused in the system settings")
        static let mirrorTitle = NSLocalizedString("booth.mirror.title", comment: "Mirror preview toggle label")
        static let mirrorDesc = NSLocalizedString("booth.mirror.desc", comment: "Mirror preview toggle description")
        static let footage = NSLocalizedString("booth.footage", comment: "Header for how much booth footage is stored")
        static let footageUsage = NSLocalizedString("booth.footage.usage", comment: "Booth footage size and pack count, takes a size and a number")
        static let deleteAll = NSLocalizedString("booth.deleteAll", comment: "Delete every booth clip")
        static let deleteAllConfirm = NSLocalizedString("booth.deleteAll.confirm", comment: "Confirm deleting every booth clip")
        static let deleteAllMessage = NSLocalizedString("booth.deleteAll.message", comment: "Warns that deleting booth footage keeps the voice takes")

        // The export sheet: which stretch of the film, and how the booth sits in it
        static let exportTitle = NSLocalizedString("booth.export.title", comment: "Export sheet title")
        static let exportSubtitle = NSLocalizedString("booth.export.subtitle", comment: "Export sheet subtitle")
        static let exportLineSubtitle = NSLocalizedString("booth.export.lineSubtitle", comment: "Export sheet subtitle when exporting a single line")
        static let cut = NSLocalizedString("booth.export.cut", comment: "Section label: which stretch of the film to export")
        static let cutFullScene = NSLocalizedString("booth.export.cut.fullScene", comment: "Export the finished dub end to end")
        static let cutSessionReel = NSLocalizedString("booth.export.cut.sessionReel", comment: "Export every dubbed line back to back")
        static let cutDetail = NSLocalizedString("booth.export.cut.detail", comment: "What the two cuts are")
        static let frameSection = NSLocalizedString("booth.export.frame", comment: "Section label: how the booth is composited")
        static let frameOff = NSLocalizedString("booth.frame.off", comment: "Booth frame: not included")
        static let frameCorner = NSLocalizedString("booth.frame.corner", comment: "Booth frame: inset in the corner")
        static let frameStacked = NSLocalizedString("booth.frame.stacked", comment: "Booth frame: scene above, booth below")
        static let frameReaction = NSLocalizedString("booth.frame.reaction", comment: "Booth frame: booth above, scene below")
        static let frameSplit = NSLocalizedString("booth.frame.split", comment: "Booth frame: side by side")
        static let stackedNote = NSLocalizedString("booth.export.stackedNote", comment: "Notes that the stacked frame renders 9:16")
        static let noFootage = NSLocalizedString("booth.export.noFootage", comment: "Shown when a scene has no booth footage to composite")
        static let includeBooth = NSLocalizedString("booth.export.includeBooth", comment: "Toggle: put the performer's own footage in the export")
        static let includeBoothDetail = NSLocalizedString("booth.export.includeBooth.detail", comment: "What turning the booth footage off leaves in a vertical export")
        static let exportConfirm = NSLocalizedString("booth.export.confirm", comment: "Render and share the export")
        static let exportLineConfirm = NSLocalizedString("booth.export.lineConfirm", comment: "Render and share a single line")
        static let exportNotice = NSLocalizedString("booth.export.notice", comment: "Says the attribution notice comes next")
        static let runtime = NSLocalizedString("booth.export.runtime", comment: "Slate field: how long the export runs")
        static let shape = NSLocalizedString("booth.export.shape", comment: "Slate field: the output frame shape")
        static let shareLine = NSLocalizedString("booth.shareLine", comment: "Share one line and its reaction")
    }

    enum Dub {
        static let unknownAuthor = NSLocalizedString("dub.unknownAuthor", comment: "Fallback pack author")
        static let importPack = NSLocalizedString("dub.importPack", comment: "Import pack button")
        static let importing = NSLocalizedString("dub.importing", comment: "Importing progress message")
        static let convertingVideo = NSLocalizedString("dub.convertingVideo", comment: "Import stage: converting the scene video")
        static let importReading = NSLocalizedString("dub.importReading", comment: "Import stage: reading the pack")
        static let delete = NSLocalizedString("dub.delete", comment: "Delete pack action")

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
        static let attribution = NSLocalizedString("dub.attribution", comment: "Header for the credit block: what the scene was cut from and under what licence")
        static let packsSection = NSLocalizedString("dub.packsSection", comment: "Packs section label")
        static let slateLines = NSLocalizedString("dub.slate.lines", comment: "Slate field: lines dubbed")
        static let slateDuration = NSLocalizedString("dub.slate.duration", comment: "Slate field: scene duration")
        static let slateCast = NSLocalizedString("dub.slate.cast", comment: "Slate field: number of characters")

        // Recording
        static let listen = NSLocalizedString("dub.listen", comment: "Listen to reference line")
        static let stop = NSLocalizedString("dub.stop", comment: "Stop button")
        static let recordTake = NSLocalizedString("dub.recordTake", comment: "Record your take")
        static let next = NSLocalizedString("dub.next", comment: "Next line")
        static let previous = NSLocalizedString("dub.previous", comment: "Previous line")
        static let recordingHint = NSLocalizedString("dub.recordingHint", comment: "Hint shown while recording a line")
        static let listenHint = NSLocalizedString("dub.listenHint", comment: "Hint shown before recording a line")
        static let playTake = NSLocalizedString("dub.playTake", comment: "Play the user's take of one line")
        static let speakerAccessibility = NSLocalizedString("dub.speakerAccessibility", comment: "Accessibility label naming who speaks the line")
        static let cast = NSLocalizedString("dub.cast", comment: "Cast list header")
        static let referenceTrack = NSLocalizedString("dub.referenceTrack", comment: "Waveform label: the pack's own audio")
        static let yourTake = NSLocalizedString("dub.yourTake", comment: "Waveform label: the user's recording")
        static let loadingScene = NSLocalizedString("dub.loadingScene", comment: "Shown while a scene's audio loads")
        static let videoNeedsReimport = NSLocalizedString("dub.videoNeedsReimport", comment: "Warning: this pack's video was converted by an older build and plays out of sync")

        // Playback
        static let original = NSLocalizedString("dub.original", comment: "Original audio mode")
        static let myDub = NSLocalizedString("dub.myDub", comment: "User dub audio mode")
        static let noTakesYet = NSLocalizedString("dub.noTakesYet", comment: "Shown when nothing has been recorded")

        // Export
        static let exporting = NSLocalizedString("dub.exporting", comment: "Export in progress")
        static let exportMixing = NSLocalizedString("dub.export.mixing", comment: "Export stage: mixing audio")
        static let exportRendering = NSLocalizedString("dub.export.rendering", comment: "Export stage: rendering video")

        static let options = NSLocalizedString("dub.options", comment: "Dub mode options menu")
        static let installingStarterPacks = NSLocalizedString("dub.installingStarterPacks", comment: "Shown while the bundled scenes are set up on first launch")

        // Scoring
        enum Score {
            static let settingTitle = NSLocalizedString("dub.score.setting.title", comment: "Toggle that turns take scoring on")
            static let settingDetail = NSLocalizedString("dub.score.setting.detail", comment: "What the scoring toggle does")
            static let sceneTitle = NSLocalizedString("dub.score.sceneTitle", comment: "Scene score panel title")
            static let notScoredYet = NSLocalizedString("dub.score.notScoredYet", comment: "Shown before any line has been dubbed")
            static let slate = NSLocalizedString("dub.score.slate", comment: "Slate field label for the scene score")
            static let lineTitle = NSLocalizedString("dub.score.lineTitle", comment: "Title above one line's score")

            static let timing = NSLocalizedString("dub.score.timing", comment: "Score component: coming in on the beat")
            static let pacing = NSLocalizedString("dub.score.pacing", comment: "Score component: syllables landing together")
            static let delivery = NSLocalizedString("dub.score.delivery", comment: "Score component: matching the performance")

            static let best = NSLocalizedString("dub.score.best", comment: "Label for the user's best line")
            static let weakest = NSLocalizedString("dub.score.weakest", comment: "Label for the line most worth re-recording")
            static let progress = NSLocalizedString("dub.score.progress", comment: "N of M lines scored, takes two integers")

            static let gradePerfect = NSLocalizedString("dub.score.grade.perfect", comment: "Top grade")
            static let gradeGreat = NSLocalizedString("dub.score.grade.great", comment: "Second grade")
            static let gradeGood = NSLocalizedString("dub.score.grade.good", comment: "Middle grade")
            static let gradeClose = NSLocalizedString("dub.score.grade.close", comment: "Fourth grade")
            static let gradeRough = NSLocalizedString("dub.score.grade.rough", comment: "Lowest grade")
        }

        enum Error {
            static let missingPackInfo = NSLocalizedString("dub.error.missingPackInfo", comment: "Pack info file missing")
            static let noLines = NSLocalizedString("dub.error.noLines", comment: "No usable lines in pack")
            static let missingAsset = NSLocalizedString("dub.error.missingAsset", comment: "Referenced asset missing, takes a filename")
            static let notAFolder = NSLocalizedString("dub.error.notAFolder", comment: "Selected item is not a pack")
            static let unreadableArchive = NSLocalizedString("dub.error.unreadableArchive", comment: "Zip could not be read, takes an error message")
            static let nothingRecorded = NSLocalizedString("dub.error.nothingRecorded", comment: "Export attempted with no takes")
            static let exportFailed = NSLocalizedString("dub.error.exportFailed", comment: "Export failed, takes an error message")
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

    // MARK: - Dub Share Notice
    enum DubShare {
        static let title = NSLocalizedString("dubShare.title", comment: "Title of the notice shown before exporting a dub")
        static let message = NSLocalizedString("dubShare.message", comment: "Explains that the export contains the original scene as well as the user's voice")
        static let cutFrom = NSLocalizedString("dubShare.cutFrom", comment: "Names the source work, %@ is e.g. 'Sprite Fright (2021), Blender Studio'")
        static let keepCredit = NSLocalizedString("dubShare.keepCredit", comment: "Asks the user to carry the credit with the export if they post it")
        static let unknownSource = NSLocalizedString("dubShare.unknownSource", comment: "Shown for a pack the user imported, whose origin the app does not know")
        static let responsibility = NSLocalizedString("dubShare.responsibility", comment: "Distributing the export is the user's own act and responsibility")
        static let confirm = NSLocalizedString("dubShare.confirm", comment: "Go ahead and export")
    }

    // MARK: - Pro / Paywall
    enum Pro {
        /// The counter in the header. Three keys rather than one with `%d`,
        /// because "1 days left" is wrong in English and worse in the languages
        /// with real plural rules.
        enum Trial {
            static let daysLeft = NSLocalizedString("pro.trial.daysLeft", comment: "Days remaining in the free trial, %d is the count, always 2 or more")
            static let oneDayLeft = NSLocalizedString("pro.trial.oneDayLeft", comment: "Exactly one day of free trial left")
            static let over = NSLocalizedString("pro.trial.over", comment: "The free trial has finished")
        }

        // Settings
        static let section = NSLocalizedString("pro.section", comment: "Settings section header for the purchase")
        static let unlockTitle = NSLocalizedString("pro.unlock.title", comment: "Settings row that opens the paywall")
        static let unlockSubtitle = NSLocalizedString("pro.unlock.subtitle", comment: "Explains what unlocking costs and gives")
        static let ownedTitle = NSLocalizedString("pro.owned.title", comment: "Settings row shown to someone who has bought the app")
        static let ownedSubtitle = NSLocalizedString("pro.owned.subtitle", comment: "Thank-you line under the owned row")
        static let manageTitle = NSLocalizedString("pro.manage.title", comment: "Opens the RevenueCat Customer Center")
        static let manageSubtitle = NSLocalizedString("pro.manage.subtitle", comment: "What the Customer Center is for")
        static let restoreTitle = NSLocalizedString("pro.restore.title", comment: "Restore a previous purchase")
        static let restoreSubtitle = NSLocalizedString("pro.restore.subtitle", comment: "Explains who the restore button is for")
        static let testStoreWarning = NSLocalizedString("pro.testStore.warning", comment: "Debug-only banner: this build talks to the RevenueCat test store")

        // Results
        static let restoredTitle = NSLocalizedString("pro.restored.title", comment: "Title of the alert after a successful restore")
        static let restoredMessage = NSLocalizedString("pro.restored.message", comment: "Body of the alert after a successful restore")
        static let nothingToRestoreTitle = NSLocalizedString("pro.nothingToRestore.title", comment: "Title when a restore found no purchase")
        static let nothingToRestoreMessage = NSLocalizedString("pro.nothingToRestore.message", comment: "Body when a restore found no purchase")
        static let errorTitle = NSLocalizedString("pro.error.title", comment: "Title of the alert after a purchase or restore failed")
        static let errorGeneric = NSLocalizedString("pro.error.generic", comment: "Fallback message when the store gave no readable reason")
        static let ok = NSLocalizedString("pro.ok", comment: "Dismisses an alert")
        static let closePaywall = NSLocalizedString("pro.closePaywall", comment: "VoiceOver label for the button that closes a dismissible paywall")

        /// The note shown once to people who had the app before it charged.
        enum EarlyAdopter {
            static let title = NSLocalizedString("pro.earlyAdopter.title", comment: "Title of the one-time note telling a pre-paywall user they keep the app free")
            static let message = NSLocalizedString("pro.earlyAdopter.message", comment: "Explains that the app is now paid but stays free for them, for life")
            static let badge = NSLocalizedString("pro.earlyAdopter.badge", comment: "Short badge naming what they have, e.g. 'Free for life'")
            static let confirm = NSLocalizedString("pro.earlyAdopter.confirm", comment: "Dismisses the note")
            static let settingsTitle = NSLocalizedString("pro.earlyAdopter.settings.title", comment: "Settings row shown to an early adopter")
            static let settingsSubtitle = NSLocalizedString("pro.earlyAdopter.settings.subtitle", comment: "Settings subtitle shown to an early adopter")

            /// The three facts, read off like a slate: label on the left, value on
            /// the right. Values are set in the timecode face, so keep them short —
            /// a wrapped monospace value breaks the row's rhythm.
            enum Row {
                static let access = NSLocalizedString("pro.earlyAdopter.row.access", comment: "Slate row label: what the early adopter can use")
                static let accessValue = NSLocalizedString("pro.earlyAdopter.row.access.value", comment: "Slate row value: both games")
                static let cost = NSLocalizedString("pro.earlyAdopter.row.cost", comment: "Slate row label: what it costs them")
                static let costValue = NSLocalizedString("pro.earlyAdopter.row.cost.value", comment: "Slate row value: nothing")
                static let expires = NSLocalizedString("pro.earlyAdopter.row.expires", comment: "Slate row label: when the access runs out")
                static let expiresValue = NSLocalizedString("pro.earlyAdopter.row.expires.value", comment: "Slate row value: never")
            }
        }

        /// The paywall the app draws itself when the dashboard's cannot be reached.
        enum Fallback {
            static let title = NSLocalizedString("pro.fallback.title", comment: "Title of the built-in paywall")
            /// Two bodies, because this screen serves two situations. Saying "your
            /// trial has ended" to someone who tapped the counter on day three is
            /// false on its face, and a paywall that opens with something the user
            /// can see is untrue reads as a trick rather than an offer.
            static let messageAfterExpiry = NSLocalizedString("pro.fallback.message", comment: "Body of the built-in paywall when the free trial is over")
            static let messageBeforeExpiry = NSLocalizedString("pro.fallback.message.beforeExpiry", comment: "Body of the built-in paywall when the user still has trial time left, so it must not claim the trial has ended")
            static let buy = NSLocalizedString("pro.fallback.buy", comment: "Buy button with the price, %@ is the localized price")
            static let buyUnpriced = NSLocalizedString("pro.fallback.buyUnpriced", comment: "Buy button before the price is known")
            static let loading = NSLocalizedString("pro.fallback.loading", comment: "Shown while the store is being asked for the price")
            static let unavailable = NSLocalizedString("pro.fallback.unavailable", comment: "The store could not be reached")
            static let retry = NSLocalizedString("pro.fallback.retry", comment: "Ask the store again")
            static let benefitOne = NSLocalizedString("pro.fallback.benefit.one", comment: "First selling point on the built-in paywall")
            static let benefitTwo = NSLocalizedString("pro.fallback.benefit.two", comment: "Second selling point on the built-in paywall")
            static let benefitThree = NSLocalizedString("pro.fallback.benefit.three", comment: "Third selling point on the built-in paywall")
            static let oneTime = NSLocalizedString("pro.fallback.oneTime", comment: "Reassures that the price is paid once, not per month")
        }
    }
}
