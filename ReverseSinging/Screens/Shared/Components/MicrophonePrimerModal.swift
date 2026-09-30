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
///
/// **A request is never left waiting.** The explanation needs a screen to be shown on, and
/// screens come and go: with none to show it on, or once the one showing it has gone, the
/// system prompt is asked for directly. The alternative is a record button that does nothing
/// for the rest of the session, which is worse than a prompt with no preamble.
final class MicrophonePrimer: ObservableObject {

    static let shared = MicrophonePrimer()

    /// The screen showing the explanation, or nil while it is not up.
    @Published private(set) var presenter: UUID?

    /// The system request, waiting for Continue.
    private var pendingRequest: (() -> Void)?

    /// The screens that can show the explanation, in the order they appeared. On the Mac
    /// several windows can each hold one, and `isFrontmost` says which the user is in.
    private var hosts: [(id: UUID, isFrontmost: Bool)] = []

    /// Shows the explanation, then runs `request`, the system prompt, once it is dismissed.
    func present(then request: @escaping () -> Void) {
        // A second press of record while the dialog is up asks nothing new.
        guard pendingRequest == nil else { return }

        guard let host = hosts.last(where: \.isFrontmost) ?? hosts.last else {
            CrashReporter.shared.recordFailure(
                "microphone_primer_no_host",
                reason: "Record was pressed on a screen that cannot show the microphone explanation"
            )
            request()
            return
        }

        pendingRequest = request
        presenter = host.id
        AnalyticsManager.shared.trackScreenViewed(screenName: "MicrophonePrimer")
    }

    func continueTapped() {
        let request = pendingRequest
        pendingRequest = nil
        presenter = nil
        request?()
    }

    // MARK: - Hosts

    func hostDidAppear(_ id: UUID, isFrontmost: Bool) {
        hosts.removeAll { $0.id == id }
        hosts.append((id, isFrontmost))
    }

    func hostDidChange(_ id: UUID, isFrontmost: Bool) {
        guard let index = hosts.firstIndex(where: { $0.id == id }) else { return }
        hosts[index].isFrontmost = isFrontmost
    }

    /// A screen went away. If it was the one showing the explanation, the explanation has
    /// been seen and still leads where it must: to the system prompt.
    func hostDidDisappear(_ id: UUID) {
        hosts.removeAll { $0.id == id }
        if presenter == id { continueTapped() }
    }
}

/// The explanation itself: what the microphone is for and where recordings stay.
struct MicrophonePrimerModal: View {

    let onContinue: () -> Void

    var body: some View {
        EditorModal(title: Strings.MicrophonePrimer.title, onClose: nil) {
            Image("studio-mic-boom")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)

            Text(Strings.MicrophonePrimer.message)
                .font(.rsBodySmall)
                .foregroundColor(.rsTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        } phoneActions: {
            BigButton(
                title: Strings.MicrophonePrimer.confirm,
                icon: "mic.fill",
                color: .rsTurquoise,
                action: onContinue,
                style: .primary,
                textFont: .rsButtonMedium
            )
        } macActions: {
            Button(Strings.MicrophonePrimer.confirm, action: onContinue)
                .keyboardShortcut(.defaultAction)
                .platformProminentButton()
        }
    }
}

// MARK: - Presentation

private struct MicrophonePrimerModifier: ViewModifier {
    @ObservedObject private var primer = MicrophonePrimer.shared
    /// This screen's name to the primer, which shows the explanation on one screen at a time.
    @State private var id = UUID()
    #if os(macOS)
    @Environment(\.controlActiveState) private var controlActiveState
    #endif

    func body(content: Content) -> some View {
        content
            .editorModal(isPresented: isShown) {
                MicrophonePrimerModal(onContinue: primer.continueTapped)
                    .interactiveDismissDisabled()
            }
            .onAppear { primer.hostDidAppear(id, isFrontmost: isFrontmost) }
            .onDisappear { primer.hostDidDisappear(id) }
            #if os(macOS)
            .onChange(of: controlActiveState) { _, _ in
                primer.hostDidChange(id, isFrontmost: isFrontmost)
            }
            #endif
    }

    /// Read-only in practice: only Continue takes the explanation down.
    private var isShown: Binding<Bool> {
        Binding(get: { primer.presenter == id }, set: { _ in })
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
    /// should have it: without one the system prompt arrives with no explanation before it.
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
