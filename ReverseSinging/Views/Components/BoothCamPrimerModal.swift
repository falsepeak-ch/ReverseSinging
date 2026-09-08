//
//  BoothCamPrimerModal.swift
//  ReverseSinging
//
//  The app's own case for the camera, made before iOS asks
//

import SwiftUI

/// Explains what Booth Cam does before the system prompt appears.
///
/// **Shown once, and only when the user reaches for the feature.** iOS gives one chance at the
/// camera prompt: a "no" there is permanent until someone finds the right row in Settings. So
/// the app states where the footage lives, that nothing leaves until an export, and that it
/// can be switched off mid-take — and only then asks. Someone who backs out here has answered
/// nothing, and the system prompt is never spent.
struct BoothCamPrimerModal: View {

    /// Called when the user turns the feature on, after the system has had its say.
    let onEnabled: () -> Void
    /// Called when the user backs out, whichever way they did it.
    let onDismiss: () -> Void

    @State private var isRequesting = false

    var body: some View {
        ZStack {
            backdrop

            panel
                .padding(.horizontal, EditorMetrics.gutter)
                .padding(.vertical, 24)
                .transition(.opacity)
        }
        .onAppear { AnalyticsManager.shared.trackScreenViewed(screenName: "BoothCamPrimer") }
    }

    // MARK: - Backdrop

    private var backdrop: some View {
        Color.rsSurface0
            .opacity(0.88)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture { dismiss() }
            .accessibilityHidden(true)
    }

    // MARK: - Panel

    private var panel: some View {
        // Three facts and a paragraph is taller than the share notice, and it has to survive
        // a small screen in a long language.
        ViewThatFits(in: .vertical) {
            panelContent
            ScrollView { panelContent }
                .scrollBounceBehavior(.basedOnSize)
        }
        .editorPanel(.rsSurface1, radius: EditorMetrics.radiusLarge)
        .frame(maxWidth: 400)
    }

    private var panelContent: some View {
        VStack(spacing: 0) {
            titleBar

            VStack(spacing: 20) {
                illustration

                VStack(spacing: 10) {
                    Text(Strings.Booth.primerTitle)
                        .font(.rsHeadingSmall)
                        .foregroundColor(.rsTextPrimary)
                        .multilineTextAlignment(.center)

                    Text(Strings.Booth.primerMessage)
                        .font(.rsBodySmall)
                        .foregroundColor(.rsTextSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                }

                facts

                VStack(spacing: 12) {
                    BigButton(
                        title: Strings.Booth.primerConfirm,
                        icon: "video.fill",
                        color: .rsTextPrimary,
                        action: enable,
                        isEnabled: !isRequesting,
                        isLoading: isRequesting,
                        style: .primary,
                        textFont: .rsButtonMedium
                    )

                    Text(Strings.Booth.primerSystemPrompt)
                        .font(.rsCaptionSmall)
                        .foregroundColor(.rsTextTertiary)
                        .multilineTextAlignment(.center)

                    Button(action: dismiss) {
                        Text(Strings.Booth.primerDecline)
                            .font(.rsButtonMedium)
                            .foregroundColor(.rsTextSecondary)
                    }
                    .disabled(isRequesting)
                }
            }
            .padding(EditorMetrics.gutter)
        }
    }

    private var titleBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text(Strings.Booth.slug)
                    .editorLabelStyle(.rsTextSecondary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                EditorToolbarButton(
                    icon: "xmark",
                    label: Strings.DubGate.close,
                    action: dismiss
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            EditorRule()
        }
    }

    private var illustration: some View {
        Image("settings-booth-cam")
            .resizable()
            .scaledToFit()
            .frame(width: 88, height: 88)
            .accessibilityHidden(true)
    }

    /// The three things that decide whether someone says yes.
    private var facts: some View {
        VStack(spacing: 0) {
            fact(
                icon: "lock.fill",
                text: Strings.Booth.factOnDevice,
                isLast: false
            )
            fact(
                icon: "square.and.arrow.up",
                text: Strings.Booth.factNothingLeaves,
                isLast: false
            )
            fact(
                icon: "video.slash.fill",
                text: Strings.Booth.factReversible,
                isLast: true
            )
        }
        .editorPanel(.rsSurface2)
    }

    private func fact(icon: String, text: String, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.rsHighlight)
                    .frame(width: 15)
                    .padding(.top, 1)

                Text(text)
                    .font(.rsMeta)
                    .foregroundColor(.rsTextPrimary)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)

            if !isLast { EditorRule() }
        }
    }

    // MARK: - Behaviour

    private func enable() {
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

    private func dismiss() {
        guard !isRequesting else { return }
        HapticManager.shared.light()
        BoothCamPreference.shared.markPrimerSeen()
        onDismiss()
    }
}

// MARK: - Presentation

private struct BoothCamPrimerModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onEnabled: () -> Void

    func body(content: Content) -> some View {
        content
            .overlay {
                if isPresented {
                    BoothCamPrimerModal(
                        onEnabled: {
                            isPresented = false
                            onEnabled()
                        },
                        onDismiss: {
                            isPresented = false
                        }
                    )
                }
            }
            .animation(.rsSmooth, value: isPresented)
    }
}

extension View {
    /// Presents the Booth Cam explanation over this view.
    func boothCamPrimer(
        isPresented: Binding<Bool>,
        onEnabled: @escaping () -> Void
    ) -> some View {
        modifier(BoothCamPrimerModifier(isPresented: isPresented, onEnabled: onEnabled))
    }
}
