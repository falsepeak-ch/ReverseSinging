//
//  DubShareNoticeModal.swift
//  ReverseSinging
//
//  Shown before every export. What leaves the device is a mix: the user's voice over
//  somebody else's picture and score. This says whose, on what terms, and that posting
//  the result is the user's own act rather than ours.
//

import SwiftUI

struct DubShareNoticeModal: View {
    /// The scene being exported. Its provenance is the whole point of the panel.
    let pack: DubPack
    /// Called when the user goes ahead with the export.
    let onConfirm: () -> Void
    /// Called when the user backs out.
    let onCancel: () -> Void

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
            AnalyticsManager.shared.trackDubShareNoticeShown(hasAttribution: pack.hasAttribution)
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
        // The credit block makes this the taller of the two modals, and it has to survive a
        // small screen in a long language.
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
                Image("megaphone")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 88, height: 88)
                    .accessibilityHidden(true)

                VStack(spacing: 10) {
                    Text(Strings.DubShare.title)
                        .font(.rsHeadingSmall)
                        .foregroundColor(.rsTextPrimary)
                        .multilineTextAlignment(.center)

                    Text(Strings.DubShare.message)
                        .font(.rsBodySmall)
                        .foregroundColor(.rsTextSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                }

                credit

                BigButton(
                    title: Strings.DubShare.confirm,
                    icon: "square.and.arrow.up",
                    color: .rsHighlight,
                    action: confirm,
                    style: .primary,
                    textFont: .rsButtonMedium
                )
            }
            .padding(EditorMetrics.gutter)
        }
    }

    private var titleBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text(pack.title)
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

    // MARK: - Credit

    /// Who made the scene, on what terms, and whose problem it is once it leaves the device.
    ///
    /// The last row is unconditional. A pack the user built or imported themselves has no
    /// provenance for us to state, and that makes the responsibility *more* clearly theirs,
    /// not less.
    private var credit: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let source = pack.source {
                row(
                    icon: "film",
                    tint: .rsTextTertiary,
                    text: String(format: Strings.DubShare.cutFrom, source)
                )

                if let rights = pack.rightsLabel {
                    row(
                        icon: "checkmark.seal",
                        tint: pack.rightsURL == nil ? .rsTextTertiary : .rsHighlight,
                        text: rights,
                        url: pack.rightsURL
                    )
                }

                row(icon: "quote.opening", tint: .rsTextTertiary, text: Strings.DubShare.keepCredit)
            } else {
                row(icon: "questionmark.circle", tint: .rsTextTertiary, text: Strings.DubShare.unknownSource)
            }

            row(
                icon: "exclamationmark.triangle.fill",
                tint: .rsCaution,
                text: Strings.DubShare.responsibility
            )
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .editorPanel(.rsSurface2)
    }

    /// One line of the credit. Tappable only where it points somewhere, a public domain
    /// finding has no deed to open, and a link that does nothing is worse than plain text.
    @ViewBuilder
    private func row(icon: String, tint: Color, text: String, url: URL? = nil) -> some View {
        let content = HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 14)

            Text(text)
                .font(.rsMeta)
                .foregroundColor(url == nil ? .rsTextSecondary : .rsHighlight)
                .multilineTextAlignment(.leading)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }

        if let url {
            Button { openURL(url) } label: { content }
                .buttonStyle(.plain)
                .accessibilityAddTraits(.isLink)
        } else {
            content
        }
    }

    // MARK: - Behaviour

    private func confirm() {
        AnalyticsManager.shared.trackDubShareNoticeAccepted()
        onConfirm()
    }

    private func cancel() {
        HapticManager.shared.light()
        onCancel()
    }
}

// MARK: - Presentation

private struct DubShareNoticeModifier: ViewModifier {
    @Binding var isPresented: Bool
    let pack: DubPack
    let onConfirm: () -> Void

    func body(content: Content) -> some View {
        content
            .overlay {
                if isPresented {
                    DubShareNoticeModal(
                        pack: pack,
                        onConfirm: {
                            isPresented = false
                            onConfirm()
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
    /// Presents the "before you share" notice over this view.
    ///
    /// Shown on every export rather than once: unlike a setting, this is a statement about the
    /// particular thing about to leave the device, and the export is the only moment it is
    /// true of anything.
    func dubShareNotice(
        isPresented: Binding<Bool>,
        pack: DubPack,
        onConfirm: @escaping () -> Void
    ) -> some View {
        modifier(DubShareNoticeModifier(isPresented: isPresented, pack: pack, onConfirm: onConfirm))
    }
}

// MARK: - Previews

private extension DubPack {
    static func previewScene(source: String?, sourceURL: String?, rights: String?) -> DubPack {
        DubPack(
            title: "Camp Rules",
            authors: ["Blender Studio", "CC BY 4.0"],
            iconFile: "shot_rex.jpg",
            backingTrackFile: "_backing_track.m4a",
            folderName: "CampRules",
            lines: [
                DubLine(
                    index: 1,
                    slug: "001_Rex",
                    character: "Rex",
                    caption: "Oy, fungus freak!",
                    imageFile: "shot_rex.jpg",
                    referenceAudioFile: "001_Rex.wav",
                    startTime: 0,
                    duration: 1.8
                )
            ],
            duration: 22.9,
            source: source,
            sourceURL: sourceURL,
            rights: rights
        )
    }

    static let previewLicensed = previewScene(
        source: "Sprite Fright (2021), Blender Studio",
        sourceURL: "https://studio.blender.org/projects/sprite-fright/",
        rights: "CC BY 4.0 - https://creativecommons.org/licenses/by/4.0/"
    )

    /// A pack the user brought themselves: nothing is known about it, which is exactly the
    /// case the notice still has to handle.
    static let previewImported = previewScene(source: nil, sourceURL: nil, rights: nil)
}


#Preview("Licensed scene") {
    ZStack {
        Color.rsSurface0.ignoresSafeArea()
        DubShareNoticeModal(pack: .previewLicensed, onConfirm: {}, onCancel: {})
    }
    .preferredColorScheme(.dark)
}

#Preview("Imported scene") {
    ZStack {
        Color.rsSurface0.ignoresSafeArea()
        DubShareNoticeModal(pack: .previewImported, onConfirm: {}, onCancel: {})
    }
    .preferredColorScheme(.dark)
}
