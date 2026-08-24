//
//  AnalyticsManager.swift
//  ReverseSinging
//
//  Centralized analytics event tracking
//

import Foundation
import FirebaseAnalytics

final class AnalyticsManager {
    static let shared = AnalyticsManager()

    private init() {}

    /// Every event goes through here so there is exactly one place that can turn
    /// tracking off. A screenshot or app-preview run drives the app through seven
    /// locales from a cold launch each time, and that is not usage.
    private func log(_ name: String, parameters: [String: Any]? = nil) {
        #if DEBUG
        if ScreenshotMode.isActive { return }
        #endif
        Analytics.logEvent(name, parameters: parameters)
    }

    // MARK: - App Lifecycle Events

    func trackAppLaunch() {
        log("app_launch", parameters: nil)
    }

    func trackOnboardingStarted() {
        log("onboarding_started", parameters: nil)
    }

    func trackOnboardingCompleted() {
        log("onboarding_completed", parameters: nil)
    }

    // MARK: - Permission Events

    func trackPermissionRequested() {
        log("permission_requested", parameters: [
            "permission_type": "microphone"
        ])
    }

    func trackPermissionGranted() {
        log("permission_granted", parameters: [
            "permission_type": "microphone"
        ])
    }

    func trackPermissionDenied() {
        log("permission_denied", parameters: [
            "permission_type": "microphone"
        ])
    }

    // MARK: - Recording Events

    func trackRecordingStarted(type: String) {
        log("recording_started", parameters: [
            "recording_type": type
        ])
    }

    func trackRecordingCompleted(type: String, duration: Double) {
        log("recording_completed", parameters: [
            "recording_type": type,
            "duration_seconds": duration
        ])
    }

    func trackRecordingFailed(type: String, error: String) {
        log("recording_failed", parameters: [
            "recording_type": type,
            "error_message": error
        ])
    }

    // MARK: - Audio Processing Events

    func trackAudioReversalStarted() {
        log("audio_reversal_started", parameters: nil)
    }

    func trackAudioReversalCompleted(duration: Double) {
        log("audio_reversal_completed", parameters: [
            "processing_time_seconds": duration
        ])
    }

    func trackAudioReversalFailed(error: String) {
        log("audio_reversal_failed", parameters: [
            "error_message": error
        ])
    }

    // MARK: - Playback Events

    func trackPlaybackStarted(recordingType: String) {
        log("playback_started", parameters: [
            "recording_type": recordingType
        ])
    }

    func trackPlaybackSpeedChanged(speed: Double) {
        log("playback_speed_changed", parameters: [
            "speed": speed
        ])
    }

    func trackPlaybackLoopToggled(enabled: Bool) {
        log("playback_loop_toggled", parameters: [
            "loop_enabled": enabled
        ])
    }

    func trackPlaybackPitchChanged(semitones: Int) {
        log("playback_pitch_changed", parameters: [
            "semitones": semitones
        ])
    }

    // MARK: - Session Events

    func trackSessionStarted() {
        log("session_started", parameters: nil)
    }

    func trackSessionCompleted(score: Double?) {
        var params: [String: Any] = [:]
        if let score = score {
            params["similarity_score"] = score
            params["grade"] = getGrade(for: score)
        }
        log("session_completed", parameters: params)
    }

    func trackSessionSaved(recordingsCount: Int) {
        log("session_saved", parameters: [
            "recordings_count": recordingsCount
        ])
    }

    func trackSessionDeleted() {
        log("session_deleted", parameters: nil)
    }

    func trackSessionListViewed(sessionsCount: Int) {
        log("session_list_viewed", parameters: [
            "saved_sessions_count": sessionsCount
        ])
    }

    // MARK: - Re-recording Events

    func trackReRecordAttempt() {
        log("re_record_attempt", parameters: nil)
    }

    func trackNewSessionFromExisting() {
        log("new_session_from_existing", parameters: nil)
    }

    // MARK: - Comparison Events

    func trackComparisonViewed(score: Double) {
        log("comparison_viewed", parameters: [
            "similarity_score": score,
            "grade": getGrade(for: score)
        ])
    }

    // MARK: - Error Events

    func trackError(category: String, message: String) {
        log("error_occurred", parameters: [
            "error_category": category,
            "error_message": message
        ])
    }

    // MARK: - Settings/Navigation Events

    func trackSettingsOpened() {
        log("settings_opened", parameters: nil)
    }

    func trackScreenViewed(screenName: String) {
        log(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName,
            AnalyticsParameterScreenClass: screenName
        ])
    }

    // MARK: - Dub Content Gate Events

    func trackDubGateShown() {
        log("dub_gate_shown", parameters: nil)
    }

    func trackDubGateOwnershipConfirmed() {
        log("dub_gate_ownership_confirmed", parameters: nil)
    }

    func trackDubGateDownloadHelpOpened() {
        log("dub_gate_download_help_opened", parameters: nil)
    }

    func trackDubGateExternalSourceOpened(source: String) {
        log("dub_gate_external_source_opened", parameters: [
            "source": source
        ])
    }

    // MARK: - Helper Methods

    private func getGrade(for score: Double) -> String {
        switch score {
        case 90...100: return "A+"
        case 85..<90:  return "A"
        case 75..<85:  return "B+"
        case 65..<75:  return "B"
        case 55..<65:  return "C+"
        case 45..<55:  return "C"
        case 40..<45:  return "D"
        default:       return "F"
        }
    }

    // MARK: - Dub Mode

    func trackDubPackImported(title: String, lineCount: Int) {
        log("dub_pack_imported", parameters: [
            "pack_title": title,
            "line_count": lineCount
        ])
    }

    func trackDubLineRecorded(lineIndex: Int, duration: Double) {
        log("dub_line_recorded", parameters: [
            "line_index": lineIndex,
            "duration": duration
        ])
    }

    /// How a single take scored. `timing` is reported alongside the overall so a run of low
    /// scores can be told apart: everyone coming in late is a latency problem to fix, everyone
    /// pacing badly is a hard scene.
    func trackDubLineScored(lineIndex: Int, score: Double, timing: Double) {
        log("dub_line_scored", parameters: [
            "line_index": lineIndex,
            "score": score,
            "timing": timing
        ])
    }

    /// Scoring is off by default, so this is how we learn whether anyone wants it.
    func trackDubScoringToggled(enabled: Bool) {
        log("dub_scoring_toggled", parameters: [
            "enabled": enabled
        ])
    }

    /// A whole scene's standing, logged when the user opens the summary.
    func trackDubSceneScored(score: Double, recordedLines: Int, totalLines: Int) {
        log("dub_scene_scored", parameters: [
            "score": score,
            "recorded_lines": recordedLines,
            "total_lines": totalLines
        ])
    }

    func trackDubPlaybackStarted(mode: String) {
        log("dub_playback_started", parameters: [
            "mode": mode
        ])
    }

    func trackDubExported(lineCount: Int, recordedCount: Int, duration: Double) {
        log("dub_exported", parameters: [
            "line_count": lineCount,
            "recorded_count": recordedCount,
            "duration": duration
        ])
    }

    // MARK: - Custom Event

    func trackCustomEvent(name: String, parameters: [String: Any]? = nil) {
        log(name, parameters: parameters)
    }
}
