//
//  BoothCamPrimerViewModel.swift
//  ReverseSinging
//
//  Asks for the camera once the app has made its case
//

import Combine

/// Behind the Booth Cam primer: the camera request, and remembering the case has been made.
///
/// What the dialog may offer depends on where the camera permission stands, for the reason
/// the 1.8.0 rejection gave about the microphone (guideline 5.1.1(iv)):
/// - **Never asked.** The explanation leads to the system prompt and nowhere else: one
///   button, no way to back out of it. The answer is given to the system, not to us.
/// - **Refused at some earlier time.** There is no prompt left to show, so the dialog says
///   the camera is off and its button opens Settings. It can be closed.
/// - **Already allowed.** The button simply turns the feature on. It can be closed.
@MainActor
final class BoothCamPrimerViewModel: ObservableObject {

    /// True while the system prompt is up, so the buttons cannot be pressed twice.
    @Published private(set) var isRequesting = false

    /// Where the camera permission stood when the dialog opened.
    let permission: BoothRecorder.CameraPermission

    /// The dialog is the explanation in front of the system prompt, so it has one way out.
    var leadsToSystemPrompt: Bool { permission == .unasked }

    /// The camera was refused before: the button opens Settings rather than asking again.
    var isRefused: Bool { permission == .refused }

    /// Called when the user turns the feature on, after the system has had its say.
    private let onEnabled: () -> Void
    /// Called when the user backs out, whichever way they did it.
    private let onDismiss: () -> Void

    init(
        permission: BoothRecorder.CameraPermission = BoothRecorder.cameraPermission,
        onEnabled: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.permission = permission
        self.onEnabled = onEnabled
        self.onDismiss = onDismiss
    }

    func onAppear() {
        AnalyticsManager.shared.trackScreenViewed(screenName: "BoothCamPrimer")
    }

    /// The dialog's main button.
    func enable() {
        guard !isRequesting else { return }

        guard !isRefused else {
            // Nothing to ask: the system already has its answer. Settings is where it changes.
            BoothCamPreference.shared.markPrimerSeen()
            AppSettings.openCamera()
            onDismiss()
            return
        }

        isRequesting = true

        Task {
            let granted = permission == .granted ? true : await BoothRecorder.requestAccess()

            isRequesting = false
            // Either way the case has been made; asking again on the next line would be
            // nagging rather than explaining.
            BoothCamPreference.shared.markPrimerSeen()

            if granted {
                AnalyticsManager.shared.trackCustomEvent(name: "booth_cam_enabled", parameters: nil)
                onEnabled()
            } else {
                // A no given to the prompt just now is an answer, and nothing follows it.
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
