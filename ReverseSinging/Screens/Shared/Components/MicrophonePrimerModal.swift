//
//  MicrophonePrimerModal.swift
//  ReverseSinging
//
//  Why the games need the microphone, said once, right before the system asks for it
//

import SwiftUI
import Combine

/// Holds the microphone request until its explanation has been read.
///
/// The first time record is pressed, the system would put up its prompt with one line of
/// text. This puts the app's own explanation in front of it: what the microphone is for, that
/// it is only on while recording, and that nothing recorded leaves the device.
///
/// App Review guideline 5.1.1(iv) allows that on one condition, which the 1.8.0 rejection
/// spelled out: the explanation must always lead to the system prompt. So the dialog has one
/// button, Continue, and no other way out. It is only ever shown while the permission is
/// still undecided; after an answer, the system's word is final and this stays out of it.
final class MicrophonePrimer: ObservableObject {

    static let shared = MicrophonePrimer()

    @Published private(set) var isPresented = false

    /// The system request, waiting for Continue.
    private var pendingRequest: (() -> Void)?

    /// Shows the explanation, then runs `request`, the system prompt, once it is dismissed.
    func present(then request: @escaping () -> Void) {
        // A second press of record while the dialog is up asks nothing new.
        guard pendingRequest == nil else { return }
        pendingRequest = request
        isPresented = true
        AnalyticsManager.shared.trackScreenViewed(screenName: "MicrophonePrimer")
    }

    func continueTapped() {
        let request = pendingRequest
        pendingRequest = nil
        isPresented = false
        request?()
    }
}

/// The explanation itself: what the microphone is for and where recordings stay.
struct MicrophonePrimerModal: View {

    let onContinue: () -> Void

    var body: some View {
        EditorModal(title: Strings.Onboarding.microphoneTitle, onClose: nil) {
            Image("studio-mic-boom")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)

            Text(Strings.Onboarding.microphoneMessage)
                .font(.rsBodySmall)
                .foregroundColor(.rsTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        } phoneActions: {
            BigButton(
                title: Strings.Onboarding.buttonMicrophoneContinue,
                icon: "mic.fill",
                color: .rsTurquoise,
                action: onContinue,
                style: .primary,
                textFont: .rsButtonMedium
            )
        } macActions: {
            Button(Strings.Onboarding.buttonMicrophoneContinue, action: onContinue)
                .keyboardShortcut(.defaultAction)
                .platformProminentButton()
        }
    }
}

// MARK: - Presentation

private struct MicrophonePrimerModifier: ViewModifier {
    @ObservedObject private var primer = MicrophonePrimer.shared
    /// This screen's own copy of the state, so that on the Mac, where several windows can
    /// each hold a recorder, only the window that asked shows the sheet.
    @State private var isShown = false
    #if os(macOS)
    @Environment(\.controlActiveState) private var controlActiveState
    #endif

    func body(content: Content) -> some View {
        content
            .editorModal(isPresented: $isShown) {
                MicrophonePrimerModal(onContinue: primer.continueTapped)
                    .interactiveDismissDisabled()
            }
            .onChange(of: primer.isPresented, initial: true) { _, isPresented in
                isShown = isPresented && isFrontmost
            }
    }

    private var isFrontmost: Bool {
        #if os(macOS)
        controlActiveState == .key
        #else
        true
        #endif
    }
}

extension View {
    /// Lets this screen show the microphone explanation. Every screen with a record button
    /// needs it: without a host the request it is holding would never be made.
    func microphonePrimer() -> some View {
        modifier(MicrophonePrimerModifier())
    }
}

#Preview {
    ZStack {
        Color.rsSurface0.ignoresSafeArea()
        MicrophonePrimerModal(onContinue: {})
    }
    .preferredColorScheme(.dark)
}
