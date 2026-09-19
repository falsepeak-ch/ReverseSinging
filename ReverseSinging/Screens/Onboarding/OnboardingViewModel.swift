//
//  OnboardingViewModel.swift
//  ReverseSinging
//
//  The onboarding pages, the microphone ask at the end of them, and finishing
//

import SwiftUI
import Combine

/// Drives onboarding: which page is up, where the microphone ask has got to, and handing the
/// user over to the app once it is done.
@MainActor
final class OnboardingViewModel: ObservableObject {

    /// Where the microphone ask on the last page stands.
    enum PermissionStep {
        /// Not asked yet, or asked and still waiting on the system.
        case undetermined
        case granted
        case denied
    }

    @Published var currentPage = 0
    @Published private(set) var permissionStep: PermissionStep = .undetermined

    /// Stops a second request while the system prompt is still up.
    private var permissionRequested = false

    private let app: AppViewModel

    let pages: [OnboardingPage] = [
        OnboardingPage(
            imageName: "microphone",
            title: Strings.Onboarding.welcomeTitle,
            description: Strings.Onboarding.welcomeMessage,
            matteColor: Color.rsSurface1
        ),
        OnboardingPage(
            imageName: "radio",
            title: Strings.Onboarding.howItWorksTitle,
            description: Strings.Onboarding.howItWorksMessage,
            matteColor: Color.rsSurface1
        ),
        // The second game gets its own page: dubbing is nothing like reverse
        // singing, and the "bring your own files" part is better said here than
        // discovered at the content gate.
        OnboardingPage(
            imageName: "clapperboard",
            title: Strings.Onboarding.dubTitle,
            description: Strings.Onboarding.dubMessage,
            matteColor: Color.rsSurface1
        ),
        // The permission ask comes last, once both games have been shown: by
        // now "we need the microphone" reads as the obvious next step rather
        // than a toll gate in front of an app the user hasn't seen yet.
        OnboardingPage(
            imageName: "studio-mic-boom",
            title: Strings.Onboarding.microphoneTitle,
            description: Strings.Onboarding.microphoneMessage,
            matteColor: Color.rsSurface1
        )
    ]

    init(app: AppViewModel) {
        self.app = app
    }

    /// The microphone ask, and the end of onboarding.
    var isOnPermissionPage: Bool { currentPage == pages.count - 1 }

    var isPermissionDenied: Bool { permissionStep == .denied }

    // MARK: - Single Button State

    /// The default reads "Continue", not "Allow": this button opens the system
    /// prompt, it is not the grant itself, and promising a permission the page
    /// cannot give is the kind of thing that reads as a dark pattern. The mic
    /// icon below is what carries the warning that a prompt is coming.
    var buttonTitle: String {
        switch permissionStep {
        case .granted: return Strings.Onboarding.buttonLetsRecord
        case .denied: return Strings.Onboarding.buttonOpenSettings
        case .undetermined: return Strings.Onboarding.buttonMicrophoneContinue
        }
    }

    var buttonIcon: String {
        switch permissionStep {
        case .granted: return "arrow.right"
        case .denied: return "gearshape.fill"
        case .undetermined: return "mic.fill"
        }
    }

    var buttonColor: Color {
        switch permissionStep {
        case .granted: return .rsTurquoise
        case .denied: return .rsWarning
        case .undetermined: return .rsTurquoise
        }
    }

    func permissionButtonTapped() {
        switch permissionStep {
        case .granted: finishOnboarding()
        case .denied: openSettings()
        case .undetermined: requestMicrophonePermission()
        }
    }

    // MARK: - Screen

    func onAppear() {
        AnalyticsManager.shared.trackOnboardingStarted()
    }

    /// Coming back from Settings with access granted should move the button on, rather than
    /// leaving the user staring at "Open Settings" again.
    func scenePhaseDidChange(_ phase: ScenePhase) {
        guard phase == .active, permissionStep == .denied else { return }
        app.checkPermissionStatus()
        guard app.hasRecordingPermission else { return }
        withAnimation(.rsSpring) {
            permissionStep = .granted
        }
    }

    // MARK: - Navigation

    func nextPage() {
        withAnimation(.rsSpring) {
            if currentPage < pages.count - 1 {
                currentPage += 1
            }
        }
        HapticManager.shared.light()
    }

    func finishOnboarding() {
        withAnimation(.rsSpring) {
            // The reverse game opens in its simple skin. The picker that used to sit
            // here is gone: choosing between two control rooms before seeing either
            // was the page everyone flicked past. Settings still offers the choice.
            app.setUIMode(.simple)
            AnalyticsManager.shared.trackOnboardingCompleted()
            app.completeOnboarding()
        }
    }

    // MARK: - Microphone

    private func requestMicrophonePermission() {
        guard !permissionRequested else { return }

        permissionRequested = true
        HapticManager.shared.light()

        AnalyticsManager.shared.trackPermissionRequested()

        app.requestPermission { [weak self] granted in
            guard let self else { return }

            withAnimation(.rsSpring) {
                self.permissionStep = granted ? .granted : .denied
            }

            if granted {
                HapticManager.shared.success()
                // Granted on the last page, drop straight into the app.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                    self?.finishOnboarding()
                }
            } else {
                HapticManager.shared.error()
            }
        }
    }

    private func openSettings() {
        HapticManager.shared.light()

        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
