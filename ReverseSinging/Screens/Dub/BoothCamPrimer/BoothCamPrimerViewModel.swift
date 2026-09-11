//
//  BoothCamPrimerViewModel.swift
//  ReverseSinging
//
//  Asks for the camera once the app has made its case
//

import Combine

/// Behind the Booth Cam primer: the camera request, and remembering the case has been made.
@MainActor
final class BoothCamPrimerViewModel: ObservableObject {

    /// True while the system prompt is up, so the buttons cannot be pressed twice.
    @Published private(set) var isRequesting = false

    /// Called when the user turns the feature on, after the system has had its say.
    private let onEnabled: () -> Void
    /// Called when the user backs out, whichever way they did it.
    private let onDismiss: () -> Void

    init(onEnabled: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.onEnabled = onEnabled
        self.onDismiss = onDismiss
    }

    func onAppear() {
        AnalyticsManager.shared.trackScreenViewed(screenName: "BoothCamPrimer")
    }

    func enable() {
        guard !isRequesting else { return }
        isRequesting = true

        Task {
            let granted: Bool

            switch BoothRecorder.cameraPermission {
            case .granted:
                granted = true
            case .unasked:
                granted = await BoothRecorder.requestAccess()
            case .refused:
                granted = false
            }

            isRequesting = false
            // Either way the case has been made; asking again on the next line would be
            // nagging rather than explaining.
            BoothCamPreference.shared.markPrimerSeen()

            if granted {
                AnalyticsManager.shared.trackCustomEvent(name: "booth_cam_enabled", parameters: nil)
                onEnabled()
            } else {
                AnalyticsManager.shared.trackPermissionDenied()
                onDismiss()
            }
        }
    }

    func dismiss() {
        guard !isRequesting else { return }
        HapticManager.shared.light()
        BoothCamPreference.shared.markPrimerSeen()
        onDismiss()
    }
}
