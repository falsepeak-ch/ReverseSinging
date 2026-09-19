//
//  DubContentGateModal.swift
//  ReverseSinging
//
//  The gate in front of every dub import. The app hosts no scenes, so the first
//  thing it does is ask whether the user has their own; if not, it points at an
//  example third-party site and says plainly that the site is not ours and that
//  the rights are the user's problem. Answering costs one tap and nothing is
//  remembered, so the disclaimers and the pointer are in front of every import
//  rather than only the first.
//

import SwiftUI

struct DubContentGateModal: View {
    enum Step {
        case ask
        case download
    }

    let source: DubContentSource
    /// Called when the user confirms the packs are already on the device.
    let onReady: () -> Void
    /// Called when the user closes the modal without confirming.
    let onCancel: () -> Void

    @State private var step: Step = .ask
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            backdrop

            panel
                .padding(.horizontal, EditorMetrics.gutter)
                .padding(.vertical, 24)
                .transition(.opacity)
        }
        .onAppear {
            AnalyticsManager.shared.trackDubGateShown()
        }
    }

    // MARK: - Backdrop

    private var backdrop: some View {
        Color.rsSurface0
            .opacity(0.88)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture { cancel() }
            .accessibilityHidden(true)
    }

    // MARK: - Panel

    private var panel: some View {
        // Tall on the download step, so it scrolls rather than overflowing a short screen.
        ViewThatFits(in: .vertical) {
            panelContent
            ScrollView { panelContent }
                .scrollBounceBehavior(.basedOnSize)
        }
        .editorPanel(.rsSurface1, radius: EditorMetrics.radiusLarge)
        .frame(maxWidth: 400)
        .animation(.rsSpring, value: step)
    }

    private var panelContent: some View {
        VStack(spacing: 0) {
            titleBar

            VStack(spacing: 20) {
                hero

                VStack(spacing: 10) {
                    Text(title)
                        .font(.rsHeadingSmall)
                        .foregroundColor(.rsTextPrimary)
                        .multilineTextAlignment(.center)

                    Text(message)
                        .font(.rsBodySmall)
                        .foregroundColor(.rsTextSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if step == .download {
                    disclaimer
                }

                actions
            }
            .padding(EditorMetrics.gutter)
        }
    }

    /// Reads like a panel header in the editor chrome rather than a floating close
    /// glyph: back on the left, what you are looking at in the middle, close on the right.
    private var titleBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                if step == .download {
                    EditorToolbarButton(
                        icon: "chevron.left",
                        label: Strings.DubGate.downloadBack,
                        action: goBack
                    )
                }

                Text(Strings.Main.Mode.dubTitle)
                    .editorLabelStyle(.rsTextSecondary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                EditorToolbarButton(
                    icon: "xmark",
                    label: Strings.DubGate.close,
                    action: cancel
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            EditorRule()
        }
    }

    private var hero: some View {
        Image(step == .ask ? "movies" : "download")
            .resizable()
            .scaledToFit()
            .frame(width: 88, height: 88)
            .accessibilityHidden(true)
    }

    // MARK: - Copy

    private var title: String {
        switch step {
        case .ask: return Strings.DubGate.askTitle
        case .download: return Strings.DubGate.downloadTitle
        }
    }

    private var message: String {
        switch step {
        case .ask: return Strings.DubGate.askMessage
        case .download: return Strings.DubGate.downloadMessage
        }
    }

    // MARK: - Disclaimer

    private var disclaimer: some View {
        VStack(alignment: .leading, spacing: 10) {
            disclaimerRow(
                icon: "link",
                tint: .rsTextTertiary,
                text: String(format: Strings.DubGate.disclaimerNotAffiliated, source.host)
            )

            disclaimerRow(
                icon: "exclamationmark.triangle.fill",
                tint: .rsCaution,
                text: Strings.DubGate.disclaimerResponsibility
            )
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .editorPanel(.rsSurface2)
    }

    private func disclaimerRow(icon: String, tint: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 14)

            Text(text)
                .font(.rsMeta)
                .foregroundColor(.rsTextSecondary)
                .multilineTextAlignment(.leading)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private var actions: some View {
        switch step {
        case .ask:
            VStack(spacing: 10) {
                BigButton(
                    title: Strings.DubGate.askConfirm,
                    icon: "checkmark",
                    color: .rsHighlight,
                    action: confirmOwnership,
                    style: .primary,
                    textFont: .rsButtonMedium
                )

                BigButton(
                    title: Strings.DubGate.askNeedDownload,
                    icon: "arrow.down",
                    color: .rsHighlight,
                    action: showDownloadStep,
                    style: .secondary,
                    textFont: .rsButtonMedium
                )
            }
        case .download:
            BigButton(
                title: String(format: Strings.DubGate.downloadOpen, source.name),
                icon: "arrow.up.right",
                color: .rsHighlight,
                action: openSource,
                style: .primary,
                textFont: .rsButtonMedium
            )
        }
    }

    // MARK: - Behaviour

    private func confirmOwnership() {
        AnalyticsManager.shared.trackDubGateOwnershipConfirmed()
        onReady()
    }

    private func showDownloadStep() {
        AnalyticsManager.shared.trackDubGateDownloadHelpOpened()
        withAnimation(.rsSpring) { step = .download }
    }

    private func goBack() {
        withAnimation(.rsSpring) { step = .ask }
    }

    private func openSource() {
        AnalyticsManager.shared.trackDubGateExternalSourceOpened(source: source.id)
        openURL(source.url)
    }

    private func cancel() {
        HapticManager.shared.light()
        onCancel()
    }
}

// MARK: - Presentation

private struct DubContentGateModifier: ViewModifier {
    @Binding var isPresented: Bool
    let source: DubContentSource
    let onReady: () -> Void

    func body(content: Content) -> some View {
        content
            .overlay {
                if isPresented {
                    DubContentGateModal(
                        source: source,
                        onReady: {
                            isPresented = false
                            onReady()
                        },
                        onCancel: {
                            isPresented = false
                        }
                    )
                }
            }
            .animation(.rsSmooth, value: isPresented)
    }
}

extension View {
    /// Presents the "do you already have your movies?" gate over this view.
    ///
    /// - Parameters:
    ///   - isPresented: Binding driving the modal.
    ///   - source: Example third-party site suggested when the user has no packs yet.
    ///   - onReady: Called once the user confirms the packs are on the device.
    func dubContentGate(
        isPresented: Binding<Bool>,
        source: DubContentSource = .example,
        onReady: @escaping () -> Void
    ) -> some View {
        modifier(DubContentGateModifier(isPresented: isPresented, source: source, onReady: onReady))
    }
}

// MARK: - Previews

#Preview("Gate") {
    ZStack {
        Color.rsSurface0.ignoresSafeArea()
        DubContentGateModal(source: .example, onReady: {}, onCancel: {})
    }
    .preferredColorScheme(.dark)
}
