//
//  GameSettingsView.swift
//  DubloonGame
//
//  Settings, drawn as the game: the set behind, ivory cards, the game's icons and switches.
//

import SwiftUI
import DubAudio

/// The game's settings. The same choices and the same view model as Dubloon's
/// (`SettingsViewModel`), laid out the way the rest of the game is: each section an ivory
/// card under a navy plaque, the outlined game icons, and switches drawn like the kit's keys.
///
/// What only the studio has stays out: the interface mode and the appearance (the game's art is
/// fixed-colour).
struct GameSettingsContent: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject private var headphones = HeadphoneMonitor.shared
    @ObservedObject private var booth = BoothCamPreference.shared
    @ObservedObject private var appIcon = AppIconPreference.shared
    let onClose: () -> Void

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 30) {
                    proSection
                    soundSection
                    if appIcon.isSupported {
                        appIconSection
                    }
                    boothSection
                    privacySection
                    aboutSection

                    if let version = viewModel.versionText {
                        Text(version)
                            .font(.game(13, weight: .semibold))
                            .foregroundStyle(Color.gameIvory.opacity(0.55))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .top) { header }
        }
        // Behind, not in the stack: the picture is wider than the screen and would widen it.
        .background { GameBackdrop() }
        .environment(\.colorScheme, .light)
        .onAppear { viewModel.onAppear() }
    }

    private var header: some View {
        ZStack {
            OutlinedText(text: Strings.Settings.title, size: 30, color: .white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 64)
            HStack {
                Spacer()
                GameRoundButton(symbol: "xmark", label: Strings.DubGate.close, diameter: 48, action: onClose)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
        // A navy band, so cards scrolling up pass under the title rather than through it.
        .background {
            LinearGradient(
                stops: [.init(color: .gameNavy, location: 0), .init(color: .gameNavy, location: 0.7), .init(color: .gameNavy.opacity(0), location: 1)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: - Sections

    private var proSection: some View {
        GameSettingsSection(title: Strings.Pro.section) {
            if viewModel.isPro {
                GameSettingsRow(icon: "game-settings-owned", title: viewModel.ownedTitle, subtitle: Strings.Pro.ownedSubtitle)
                GameSettingsRow(
                    icon: "game-settings-manage-purchase",
                    title: viewModel.manageTitle,
                    subtitle: viewModel.manageSubtitle,
                    trailing: .chevron,
                    action: viewModel.openCustomerCenter
                )
            } else {
                GameSettingsRow(
                    icon: "game-settings-unlock",
                    title: Strings.Pro.unlockTitle,
                    subtitle: GameStrings.Settings.unlockDesc,
                    trailing: .chevron,
                    isHighlighted: true,
                    action: viewModel.showPaywall
                )
            }
            GameSettingsRow(
                icon: "game-settings-restore-purchase",
                title: Strings.Pro.restoreTitle,
                subtitle: Strings.Pro.restoreSubtitle,
                trailing: viewModel.isRestoring ? .busy : .chevron,
                action: viewModel.restore
            )
        }
    }

    private var soundSection: some View {
        GameSettingsSection(title: Strings.Settings.preferences) {
            GameSettingsToggle(
                icon: "game-settings-haptics",
                title: Strings.Settings.hapticFeedback,
                subtitle: Strings.Settings.hapticFeedbackDesc,
                isOn: Binding(get: { viewModel.hapticsEnabled }, set: { viewModel.setHapticsEnabled($0) })
            )
            GameSettingsToggle(
                icon: "game-settings-sound",
                title: Strings.Settings.soundEffects,
                subtitle: GameStrings.Settings.soundEffectsDesc,
                isOn: Binding(get: { viewModel.soundsEnabled }, set: { viewModel.setSoundsEnabled($0) })
            )
            GameSettingsToggle(
                icon: "game-settings-sound",
                title: GameStrings.Settings.fewerSounds,
                subtitle: GameStrings.Settings.fewerSoundsDesc,
                isOn: Binding(get: { viewModel.fewerSounds }, set: { viewModel.setFewerSounds($0) }),
                isEnabled: viewModel.soundsEnabled
            )
            GameSettingsToggle(
                icon: "game-headphones",
                title: Strings.Settings.headphoneMonitor,
                subtitle: headphones.isHeadphonesConnected
                    ? Strings.Settings.headphoneMonitorDesc
                    : Strings.Settings.headphoneMonitorUnavailable,
                isOn: $headphones.isEnabled
            )
            .onAppear { headphones.refresh() }
        }
    }

    private var appIconSection: some View {
        GameSettingsSection(title: Strings.Settings.appIcon) {
            HStack(spacing: 12) {
                ForEach(AppIconChoice.allCases) { choice in
                    let isSelected = appIcon.current == choice
                    Button {
                        HapticManager.shared.selection()
                        GameSFX.play(.tap)
                        appIcon.set(choice)
                    } label: {
                        VStack(spacing: 8) {
                            Image(choice.previewAssetName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 72 * 0.225, style: .continuous))
                                .accessibilityHidden(true)
                            Text(choice.title)
                                .font(.gameDisplay(17))
                                .foregroundStyle(Color.gameNavy)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background {
                            RoundedRectangle(cornerRadius: 18)
                                .fill(isSelected ? Color.gameCyan.opacity(0.2) : Color.clear)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 18)
                                .strokeBorder(isSelected ? Color.gameNavy : Color.clear, lineWidth: 2)
                        }
                    }
                    .buttonStyle(CardPressStyle())
                    .accessibilityLabel(choice.title)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    private var boothSection: some View {
        GameSettingsSection(title: Strings.Booth.settingsSection) {
            GameSettingsToggle(
                icon: "game-settings-booth-cam",
                title: Strings.Booth.settingsTitle,
                subtitle: viewModel.isBoothDenied ? Strings.Booth.settingsDenied : Strings.Booth.settingsDesc,
                isOn: Binding(get: { booth.isEnabled }, set: { viewModel.setBoothEnabled($0) }),
                isEnabled: !viewModel.isBoothDenied
            )
            if booth.isEnabled {
                GameSettingsToggle(
                    icon: "game-settings-mirror-preview",
                    title: Strings.Booth.mirrorTitle,
                    subtitle: Strings.Booth.mirrorDesc,
                    isOn: $booth.mirrorsPreview
                )
            }
            if viewModel.boothUsage.bytes > 0 {
                GameSettingsRow(
                    icon: "game-settings-privacy",
                    title: Strings.Booth.deleteAll,
                    subtitle: String(
                        format: Strings.Booth.footageUsage,
                        ByteCountFormatter.string(fromByteCount: viewModel.boothUsage.bytes, countStyle: .file),
                        viewModel.boothUsage.packs
                    ),
                    trailing: .chevron
                ) { viewModel.isConfirmingBoothDelete = true }
            }
        }
        .onAppear { viewModel.refreshBoothUsage() }
        .alert(Strings.Booth.deleteAll, isPresented: $viewModel.isConfirmingBoothDelete) {
            Button(Strings.Booth.deleteAllConfirm, role: .destructive) { viewModel.deleteBoothFootage() }
            Button(Strings.Main.Alert.cancel, role: .cancel) {}
        } message: {
            Text(Strings.Booth.deleteAllMessage)
        }
    }

    private var privacySection: some View {
        GameSettingsSection(title: Strings.Settings.privacySection) {
            GameSettingsToggle(
                icon: "game-settings-usage-data",
                title: Strings.Settings.shareUsage,
                subtitle: Strings.Settings.shareUsageDesc,
                isOn: Binding(get: { viewModel.sharesUsageData }, set: { viewModel.setSharesUsageData($0) })
            )
        }
    }

    private var aboutSection: some View {
        GameSettingsSection(title: Strings.Settings.about) {
            GameSettingsRow(
                icon: viewModel.isPro ? "game-settings-owned" : "game-settings-unlock",
                title: viewModel.licenseText,
                subtitle: viewModel.memberSinceText ?? ""
            )
            GameSettingsRow(
                icon: "game-settings-help",
                title: Strings.Settings.help,
                subtitle: Strings.Settings.helpDesc,
                trailing: .chevron,
                action: viewModel.openHelp
            )
            GameSettingsRow(
                icon: "game-settings-privacy",
                title: Strings.Settings.privacyPolicy,
                subtitle: Strings.Settings.privacyPolicyDesc,
                trailing: .external,
                action: viewModel.openPrivacyPolicy
            )
            GameSettingsRow(
                icon: "game-settings-terms",
                title: Strings.Pro.Fallback.terms,
                subtitle: Strings.Settings.termsDesc,
                trailing: .external,
                action: viewModel.openTerms
            )
            GameSettingsRow(
                icon: "game-swiss-flag",
                title: Strings.Settings.builtInSwitzerland,
                subtitle: Strings.Settings.builtInSwitzerlandDesc
            )
        }
    }
}

// MARK: - Pieces

/// A section: its title on a navy plaque hanging over an ivory card, its rows inside.
private struct GameSettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 2) {
            content
        }
        .padding(.top, 18)
        .padding(.bottom, 4)
        .gameCard(radius: 24, lip: 5)
        .overlay(alignment: .topLeading) {
            Text(title.uppercased())
                .font(.gameDisplay(15))
                .tracking(0.8)
                .foregroundStyle(Color.gameCyan)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.gameNavy))
                .offset(x: 18, y: -15)
                .accessibilityAddTraits(.isHeader)
        }
    }
}

/// One row: the game icon, a title in the display face, the explanation under it, and what
/// the row does at its end.
private struct GameSettingsRow: View {
    enum Trailing { case none, chevron, external, busy }

    let icon: String
    let title: String
    let subtitle: String
    var trailing: Trailing = .none
    var isHighlighted = false
    var action: (() -> Void)?

    var body: some View {
        if let action {
            Button {
                HapticManager.shared.light()
                GameSFX.play(.tap)
                action()
            } label: { content }
            .buttonStyle(CardPressStyle())
            .disabled(trailing == .busy)
        } else {
            content
        }
    }

    private var content: some View {
        HStack(spacing: 14) {
            Image(icon)
                .resizable()
                .scaledToFit()
                .frame(width: 46, height: 46)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.gameDisplay(19))
                    .foregroundStyle(isHighlighted ? Color(gameHex: 0x1B7E9C) : .gameNavy)
                    .fixedSize(horizontal: false, vertical: true)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.game(14, weight: .medium))
                        .foregroundStyle(Color.gameNavy.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)

            switch trailing {
            case .none: EmptyView()
            case .busy: ProgressView().tint(.gameNavy)
            case .chevron, .external:
                Image(systemName: trailing == .external ? "arrow.up.right" : "chevron.right")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Color.gameNavy)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(isHighlighted ? Color.gameCyan : Color.gameNavy.opacity(0.08)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

/// A preference row with the game's switch.
private struct GameSettingsToggle: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    var isEnabled = true

    var body: some View {
        HStack(spacing: 14) {
            Image(icon)
                .resizable()
                .scaledToFit()
                .frame(width: 46, height: 46)
                .saturation(isOn && isEnabled ? 1 : 0)
                .opacity(isOn && isEnabled ? 1 : 0.55)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.gameDisplay(19))
                    .foregroundStyle(Color.gameNavy)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.game(14, weight: .medium))
                    .foregroundStyle(Color.gameNavy.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(GameSwitchStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
    }
}

/// The kit's switch: a track with the navy outline and lip every key in the game has, cyan
/// when on and pale when off, and an ivory knob inset from the outline so the two never merge.
struct GameSwitchStyle: ToggleStyle {
    private let width: CGFloat = 60
    private let height: CGFloat = 34
    private let knob: CGFloat = 22

    func makeBody(configuration: Configuration) -> some View {
        let on = configuration.isOn
        Button {
            HapticManager.shared.selection()
            GameSFX.play(.tap)
            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) { configuration.isOn.toggle() }
        } label: {
            ZStack {
                // The lip, then the track on it.
                Capsule().fill(Color.gameNavy).offset(y: 3)
                Capsule().fill(on ? Color.gameCyan : Color(gameHex: 0xDCE3E8))
                Capsule()
                    .fill(.white.opacity(on ? 0.35 : 0.6))
                    .frame(height: 3)
                    .padding(.horizontal, 14)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 6)
                Capsule().strokeBorder(Color.gameNavy, lineWidth: 3)

                Circle()
                    .fill(Color.gameIvory)
                    .overlay(Circle().strokeBorder(Color.gameNavy, lineWidth: 2.5))
                    .frame(width: knob, height: knob)
                    .offset(x: (on ? 1 : -1) * (width / 2 - knob / 2 - 6))
            }
            .frame(width: width, height: height)
            .padding(.bottom, 3)
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation { Toggle(isOn: configuration.$isOn) { configuration.label } }
    }
}
