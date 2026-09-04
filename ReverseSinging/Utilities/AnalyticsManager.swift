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

    /// Fired when we hand the review prompt to StoreKit. Apple decides whether it is
    /// actually shown, so this measures our asking, not their seeing.
    func trackReviewPromptRequested(trigger: String, openCount: Int, sharedVideoCount: Int) {
        log("review_prompt_requested", parameters: [
            "trigger": trigger,
            "open_count": openCount,
            "shared_video_count": sharedVideoCount
        ])
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

    func trackSessionListViewed(sessionsCount: Int) {
        log("session_list_viewed", parameters: [
            "saved_sessions_count": sessionsCount
        ])
    }

    func trackNewSessionFromExisting() {
        log("new_session_from_existing", parameters: nil)
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

    // MARK: - Dub Share Notice

    /// Fired on every export attempt, so the accept rate below is a rate rather than a count.
    /// `has_attribution` separates the shipped scenes from packs the user brought themselves.
    func trackDubShareNoticeShown(hasAttribution: Bool) {
        log("dub_share_notice_shown", parameters: [
            "has_attribution": hasAttribution
        ])
    }

    func trackDubShareNoticeAccepted() {
        log("dub_share_notice_accepted", parameters: nil)
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

    /// Firebase drops a string parameter longer than 100 characters, and drops it silently:
    /// the event still arrives, just without that field. Pack titles and author lists are
    /// written by whoever made the pack, so neither has a length we control.
    private func truncated(_ value: String, limit: Int = 100) -> String {
        value.count <= limit ? value : String(value.prefix(limit - 1)) + "…"
    }

    /// A pack the user brought themselves, as it landed.
    ///
    /// This is the only view we get of what the community is actually making: the packs
    /// live on other people's devices and on sites we do not run, so what is imported here
    /// is the whole sample. `pack_title` and `authors` are what the pack's own
    /// `_pack_info.ini` claims; `source_name` is what the file was called when the user
    /// picked it, which is often the more recognisable name of the two.
    ///
    /// Only user imports reach this. The bundled starter packs install through
    /// `DubStarterPacks`, which calls the importer directly, so they never inflate it.
    func trackDubPackImported(
        title: String,
        authors: [String],
        sourceName: String,
        lineCount: Int,
        characterCount: Int,
        duration: Double,
        hasVideo: Bool,
        hasAttribution: Bool
    ) {
        log("dub_pack_imported", parameters: [
            "pack_title": truncated(title),
            "authors": truncated(authors.joined(separator: ", ")),
            "source_name": truncated(sourceName),
            "line_count": lineCount,
            "character_count": characterCount,
            "duration": duration,
            "has_video": hasVideo,
            "has_attribution": hasAttribution
        ])
    }

    /// An import that threw.
    ///
    /// Worth as much as the successful ones: a pack that will not open is a pack somebody
    /// made and could not use, and the name is the only way to go and find out why. There is
    /// no parsed title at this point, so the file the user picked is the name we have.
    func trackDubPackImportFailed(sourceName: String, reason: String) {
        log("dub_pack_import_failed", parameters: [
            "source_name": truncated(sourceName),
            "reason": truncated(reason)
        ])
    }

    /// Which packs are actually performed, as opposed to merely imported. An import is
    /// curiosity; opening the recorder is the pack earning its place.
    func trackDubPackOpened(title: String, lineCount: Int, recordedCount: Int) {
        log("dub_pack_opened", parameters: [
            "pack_title": truncated(title),
            "line_count": lineCount,
            "recorded_count": recordedCount
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

    // MARK: - Purchases

    /// The paywall reached the screen. `source` says what put it there — the
    /// expired trial, the counter in the header, or the settings row — which is
    /// the only way to tell a hard paywall's numbers apart from an offer someone
    /// chose to look at.
    func trackPaywallShown(source: String, isHardPaywall: Bool) {
        log("paywall_shown", parameters: [
            "source": source,
            "is_hard_paywall": isHardPaywall
        ])
    }

    func trackPaywallDismissed(source: String) {
        log("paywall_dismissed", parameters: [
            "source": source
        ])
    }

    func trackPurchaseCompleted(productID: String, source: String) {
        log("purchase_completed", parameters: [
            "product_id": productID,
            "source": source
        ])
    }

    func trackPurchaseFailed(reason: String) {
        log("purchase_failed", parameters: [
            "reason": reason
        ])
    }

    func trackRestoreCompleted(foundEntitlement: Bool) {
        log("restore_completed", parameters: [
            "found_entitlement": foundEntitlement
        ])
    }

    func trackRestoreFailed(reason: String) {
        log("restore_failed", parameters: [
            "reason": reason
        ])
    }

    /// Fired once, on the launch that finds the free window closed.
    func trackTrialExpired(trialLengthInDays: Int) {
        log("trial_expired", parameters: [
            "trial_length_days": trialLengthInDays
        ])
    }

    /// Fired once per install, when the grandfather clause is applied. `source`
    /// says which signal found them — the traces on the device, or the receipt
    /// after a reinstall — which is the only way to tell whether the receipt
    /// fallback is earning its keep.
    func trackEarlyAdopterGranted(source: String) {
        log("early_adopter_granted", parameters: [
            "source": source
        ])
    }

    func trackEarlyAdopterWelcomeShown() {
        log("early_adopter_welcome_shown", parameters: nil)
    }

    func trackCustomerCenterOpened() {
        log("customer_center_opened", parameters: nil)
    }

    // MARK: - Custom Event

    func trackCustomEvent(name: String, parameters: [String: Any]? = nil) {
        log(name, parameters: parameters)
    }
}
