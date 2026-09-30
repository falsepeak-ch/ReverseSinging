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
/// can be switched off mid-take — and only then asks.
///
/// While the camera has never been asked for, the dialog has one button and no way round it:
/// App Review requires that an explanation like this always leads to the system prompt, where
/// the user gives their answer. Once there is an answer, the dialog can be closed like any
/// other; see `BoothCamPrimerViewModel`.
struct BoothCamPrimerModal: View {

    @StateObject private var viewModel: BoothCamPrimerViewModel

    /// - Parameters:
    ///   - onEnabled: called when the user turns the feature on, after the system has had its say.
    ///   - onDismiss: called when the user backs out, whichever way they did it.
    init(onEnabled: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: BoothCamPrimerViewModel(
            onEnabled: onEnabled,
            onDismiss: onDismiss
        ))
    }

    var body: some View {
        EditorModal(title: Strings.Booth.slug, onClose: closeAction) {
            illustration

            VStack(spacing: 10) {
                Text(Strings.Booth.primerTitle)
                    .font(.rsHeadingSmall)
                    .foregroundColor(.rsTextPrimary)
                    .multilineTextAlignment(.center)

                Text(primerMessage)
                    .font(.rsBodySmall)
                    .foregroundColor(.rsTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }

            facts

            #if os(macOS)
            noteText
            #endif
        } phoneActions: {
            VStack(spacing: 12) {
                BigButton(
                    title: confirmTitle,
                    icon: viewModel.isRefused ? "gearshape.fill" : "video.fill",
                    color: .rsTextPrimary,
                    action: viewModel.enable,
                    isEnabled: !viewModel.isRequesting,
                    isLoading: viewModel.isRequesting,
                    style: .primary,
                    textFont: .rsButtonMedium
                )

                noteText

                if !viewModel.leadsToSystemPrompt {
                    Button(action: viewModel.dismiss) {
                        Text(Strings.Booth.primerDecline)
                            .font(.rsButtonMedium)
                            .foregroundColor(.rsTextSecondary)
                    }
                    .disabled(viewModel.isRequesting)
                }
            }
        } macActions: {
            if viewModel.isRequesting {
                ProgressView().controlSize(.small)
            }
            Button(confirmTitle, action: viewModel.enable)
                .keyboardShortcut(.defaultAction)
                .platformProminentButton()
                .disabled(viewModel.isRequesting)
        }
        .interactiveDismissDisabled(viewModel.leadsToSystemPrompt)
        .onAppear { viewModel.onAppear() }
    }

    /// Nil while the dialog is the explanation in front of the system prompt.
    private var closeAction: (() -> Void)? {
        viewModel.leadsToSystemPrompt ? nil : { viewModel.dismiss() }
    }

    private var confirmTitle: String {
        viewModel.isRefused ? Strings.Main.EmptyState.button : Strings.Booth.primerConfirm
    }

    /// The line under the button: that the system asks next, or, after an earlier refusal,
    /// that the camera is off and Settings is where to change it.
    private var note: String? {
        if viewModel.isRefused { return Strings.Booth.settingsDenied }
        guard viewModel.leadsToSystemPrompt else { return nil }
        #if os(macOS)
        return Strings.Booth.primerSystemPromptMac
        #else
        return Strings.Booth.primerSystemPrompt
        #endif
    }

    @ViewBuilder
    private var noteText: some View {
        if let note {
            Text(note)
                .font(.rsCaptionSmall)
                .foregroundColor(.rsTextTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var primerMessage: String {
        #if os(macOS)
        Strings.Booth.primerMessageMac
        #else
        Strings.Booth.primerMessage
        #endif
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
}

// MARK: - Presentation

private struct BoothCamPrimerModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onEnabled: () -> Void

    func body(content: Content) -> some View {
        content.editorModal(isPresented: $isPresented) {
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
