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

    // MARK: - App Lifecycle Events

    func trackAppLaunch() {
        Analytics.logEvent("app_launch", parameters: nil)
    }

    func trackOnboardingStarted() {
        Analytics.logEvent("onboarding_started", parameters: nil)
    }

    func trackOnboardingCompleted() {
        Analytics.logEvent("onboarding_completed", parameters: nil)
    }

    // MARK: - Permission Events

    func trackPermissionRequested() {
        Analytics.logEvent("permission_requested", parameters: [
            "permission_type": "microphone"
        ])
    }

    func trackPermissionGranted() {
        Analytics.logEvent("permission_granted", parameters: [
            "permission_type": "microphone"
        ])
    }

    func trackPermissionDenied() {
        Analytics.logEvent("permission_denied", parameters: [
            "permission_type": "microphone"
        ])
    }

    // MARK: - Recording Events

    func trackRecordingStarted(type: String) {
        Analytics.logEvent("recording_started", parameters: [
            "recording_type": type
        ])
    }

    func trackRecordingCompleted(type: String, duration: Double) {
        Analytics.logEvent("recording_completed", parameters: [
            "recording_type": type,
            "duration_seconds": duration
        ])
    }

    func trackRecordingFailed(type: String, error: String) {
        Analytics.logEvent("recording_failed", parameters: [
            "recording_type": type,
            "error_message": error
        ])
    }

    // MARK: - Audio Processing Events

    func trackAudioReversalStarted() {
        Analytics.logEvent("audio_reversal_started", parameters: nil)
    }

    func trackAudioReversalCompleted(duration: Double) {
        Analytics.logEvent("audio_reversal_completed", parameters: [
            "processing_time_seconds": duration
        ])
    }

    func trackAudioReversalFailed(error: String) {
        Analytics.logEvent("audio_reversal_failed", parameters: [
            "error_message": error
        ])
    }

    // MARK: - Playback Events

    func trackPlaybackStarted(recordingType: String) {
        Analytics.logEvent("playback_started", parameters: [
            "recording_type": recordingType
        ])
    }

    func trackPlaybackSpeedChanged(speed: Double) {
        Analytics.logEvent("playback_speed_changed", parameters: [
            "speed": speed
        ])
    }

    func trackPlaybackLoopToggled(enabled: Bool) {
        Analytics.logEvent("playback_loop_toggled", parameters: [
            "loop_enabled": enabled
        ])
    }

    func trackPlaybackPitchChanged(semitones: Int) {
        Analytics.logEvent("playback_pitch_changed", parameters: [
            "semitones": semitones
        ])
    }

    // MARK: - Session Events

    func trackSessionStarted() {
        Analytics.logEvent("session_started", parameters: nil)
    }

    func trackSessionCompleted(score: Double?) {
        var params: [String: Any] = [:]
        if let score = score {
            params["similarity_score"] = score
            params["grade"] = getGrade(for: score)
        }
        Analytics.logEvent("session_completed", parameters: params)
    }

    func trackSessionSaved(recordingsCount: Int) {
        Analytics.logEvent("session_saved", parameters: [
            "recordings_count": recordingsCount
        ])
    }

    func trackSessionDeleted() {
        Analytics.logEvent("session_deleted", parameters: nil)
    }

    func trackSessionListViewed(sessionsCount: Int) {
        Analytics.logEvent("session_list_viewed", parameters: [
            "saved_sessions_count": sessionsCount
        ])
    }

    // MARK: - Re-recording Events

    func trackReRecordAttempt() {
        Analytics.logEvent("re_record_attempt", parameters: nil)
    }

    func trackNewSessionFromExisting() {
        Analytics.logEvent("new_session_from_existing", parameters: nil)
    }

    // MARK: - Comparison Events

    func trackComparisonViewed(score: Double) {
        Analytics.logEvent("comparison_viewed", parameters: [
            "similarity_score": score,
            "grade": getGrade(for: score)
        ])
    }

    // MARK: - Error Events

    func trackError(category: String, message: String) {
        Analytics.logEvent("error_occurred", parameters: [
            "error_category": category,
            "error_message": message
        ])
    }

    // MARK: - Settings/Navigation Events

    func trackSettingsOpened() {
        Analytics.logEvent("settings_opened", parameters: nil)
    }

    func trackScreenViewed(screenName: String) {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName,
            AnalyticsParameterScreenClass: screenName
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

    // MARK: - Custom Event

    func trackCustomEvent(name: String, parameters: [String: Any]? = nil) {
        Analytics.logEvent(name, parameters: parameters)
    }
}
