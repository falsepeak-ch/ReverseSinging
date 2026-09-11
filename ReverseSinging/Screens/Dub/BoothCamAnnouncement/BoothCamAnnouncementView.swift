//
//  BoothCamAnnouncementView.swift
//  ReverseSinging
//
//  The note that tells someone who updated that the booth exists
//

import SwiftUI

/// Shown once, to people who were dubbing before Booth Cam arrived. See `BoothCamAnnouncement`.
///
/// Set like `EarlyAdopterWelcomeView`: the clapper band, a tracked label, a leading-aligned
/// illustration and a slate of labelled rows, because it is the same kind of screen, a fact
/// about this app told plainly and once. Not a primer and not a permission ask: the camera is
/// not requested here and nothing is switched on. The primer does that, when the user reaches
/// for the key, and the slate says where the key is.
struct BoothCamAnnouncementView: View {

    /// Called when the user wants to go and try it, after the sheet has dismissed itself.
    let onTryIt: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.rsSurface0.ignoresSafeArea()

            VStack(spacing: 0) {
                ClapperBand()

                // Scrolled rather than fixed, for the same reason the early-adopter note is:
                // the message runs to seven lines in some languages, and a screen announcing
                // a feature must not clip its own last line.
                GeometryReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            EditorSectionHeader(title: Strings.WhatsNew.badge)

                            illustration
                                .padding(.top, 28)

                            Text(Strings.WhatsNew.Booth.title)
                                .font(.rsDisplayMedium)
                                .foregroundStyle(Color.rsTextPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 26)

                            Text(Strings.WhatsNew.Booth.message)
                                .font(.rsBodyMedium)
                                .foregroundStyle(Color.rsTextSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 14)

                            slate
                                .padding(.top, 28)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, EditorMetrics.gutter)
                        .padding(.vertical, 32)
                        .frame(minHeight: proxy.size.height, alignment: .center)
                    }
                }

                footer
            }
        }
        .onAppear { AnalyticsManager.shared.trackScreenViewed(screenName: "BoothCamAnnouncement") }
    }

    // MARK: - Pieces

    private var illustration: some View {
        Image("settings-booth-cam")
            .resizable()
            .scaledToFit()
            .frame(width: 116, height: 116)
            .accessibilityHidden(true)
    }

    /// The three things someone needs before they will go looking: where the switch is,
    /// where the footage goes, and that nothing has changed until they touch it.
    private var slate: some View {
        VStack(spacing: 0) {
            slateRow(
                label: Strings.WhatsNew.Booth.rowSwitch,
                value: Strings.WhatsNew.Booth.rowSwitchValue,
                icon: "video.fill"
            )

            EditorRule()

            slateRow(
                label: Strings.WhatsNew.Booth.rowFootage,
                value: Strings.WhatsNew.Booth.rowFootageValue,
                icon: "lock.fill"
            )

            EditorRule()

            slateRow(
                label: Strings.WhatsNew.Booth.rowDefault,
                value: Strings.WhatsNew.Booth.rowDefaultValue
            )
        }
        .editorPanel()
    }

    private func slateRow(label: String, value: String, icon: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .editorLabelStyle()

            Spacer(minLength: 8)

            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.rsHighlight)
                    .accessibilityHidden(true)
            }

            Text(value)
                .font(.rsTimecode)
                .foregroundStyle(Color.rsTextPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Button {
                HapticManager.shared.medium()
                dismiss()
                onTryIt()
            } label: {
                Text(Strings.WhatsNew.Booth.confirm)
                    .font(.rsButtonLarge)
                    .foregroundStyle(Color.rsSurface0)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: EditorMetrics.radius, style: .continuous)
                            .fill(Color.rsTextPrimary)
                    )
            }
            .buttonStyle(ScaleButtonStyle())

            Button {
                HapticManager.shared.light()
                dismiss()
            } label: {
                Text(Strings.WhatsNew.Booth.later)
                    .font(.rsButtonMedium)
                    .foregroundStyle(Color.rsTextSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
            }
        }
        .padding(.horizontal, EditorMetrics.gutter)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .background(Color.rsSurface1.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { EditorRule() }
    }
}

#Preview {
    BoothCamAnnouncementView(onTryIt: {})
        .preferredColorScheme(.dark)
}
