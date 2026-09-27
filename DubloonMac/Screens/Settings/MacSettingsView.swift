//
//  MacSettingsView.swift
//  DubloonMac
//
//  Dubloon ▸ Settings…: a tabbed preferences window, the Mac's shape for the iPhone's settings
//

import SwiftUI
import DubAudio

struct MacSettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    @ObservedObject private var headphones = HeadphoneMonitor.shared
    @ObservedObject private var booth = BoothCamPreference.shared
    @ObservedObject private var scoring = DubScoringPreference.shared

    init(app: AppViewModel) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(app: app, scope: .app))
    }

    var body: some View {
        TabView {
            general
                .tabItem { Label(MacStrings.Settings.general, systemImage: "gearshape") }

            recording
                .tabItem { Label(MacStrings.Settings.recording, systemImage: "mic") }

            account
                .tabItem { Label(Strings.Pro.section, systemImage: "sparkles") }

            about
                .tabItem { Label(Strings.Settings.about, systemImage: "info.circle") }
        }
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            viewModel.onAppear()
            viewModel.refreshBoothUsage()
            headphones.refresh()
        }
        .sheet(isPresented: $viewModel.isPaywallPresented) {
            ProPaywallView(source: "settings")
        }
        .alert(Strings.Booth.deleteAll, isPresented: $viewModel.isConfirmingBoothDelete) {
            Button(Strings.Booth.deleteAllConfirm, role: .destructive) { viewModel.deleteBoothFootage() }
            Button(Strings.Main.Alert.cancel, role: .cancel) {}
        } message: {
            Text(Strings.Booth.deleteAllMessage)
        }
        // A restore from the Pro tab answers here, not by closing the window.
        .purchaseAlerts()
        .preferredColorScheme(.dark)

    }

    // MARK: - Tabs

    private var general: some View {
        Form {
            Section {
                Toggle(isOn: Binding(get: { viewModel.soundsEnabled }, set: { viewModel.setSoundsEnabled($0) })) {
                    Text(Strings.Settings.soundEffects)
                    Text(Strings.Settings.soundEffectsDesc)
                }
            }

            Section {
                Toggle(isOn: $scoring.isEnabled) {
                    Text(Strings.Dub.Score.settingTitle)
                    Text(Strings.Dub.Score.settingDetail)
                }
            } header: {
                Text(GameMode.dub.title)
            }
        }
        .formStyle(.grouped)
    }

    private var recording: some View {
        Form {
            Section {
                Toggle(isOn: $headphones.isEnabled) {
                    Text(Strings.Settings.headphoneMonitor)
                    Text(headphones.isHeadphonesConnected
                         ? Strings.Settings.headphoneMonitorDesc
                         : Strings.Settings.headphoneMonitorUnavailable)
                }
            }

            Section {
                Toggle(isOn: Binding(get: { booth.isEnabled }, set: { viewModel.setBoothEnabled($0) })) {
                    Text(Strings.Booth.settingsTitle)
                    Text(viewModel.isBoothDenied ? Strings.Booth.settingsDenied : Strings.Booth.settingsDesc)
                }
                .disabled(viewModel.isBoothDenied)

                if booth.isEnabled {
                    Toggle(isOn: $booth.mirrorsPreview) {
                        Text(Strings.Booth.mirrorTitle)
                        Text(Strings.Booth.mirrorDesc)
                    }
                }

                if viewModel.boothUsage.bytes > 0 {
                    LabeledContent(Strings.Booth.footage) {
                        HStack {
                            Text(String(
                                format: Strings.Booth.footageUsage,
                                ByteCountFormatter.string(fromByteCount: viewModel.boothUsage.bytes, countStyle: .file),
                                viewModel.boothUsage.packs
                            ))
                            .foregroundColor(.secondary)
                            Button(Strings.Booth.deleteAll, role: .destructive) {
                                viewModel.isConfirmingBoothDelete = true
                            }
                        }
                    }
                }
            } header: {
                Text(Strings.Booth.settingsSection)
            }
        }
        .formStyle(.grouped)
    }

    private var account: some View {
        Form {
            Section {
                if viewModel.isEarlyAdopter {
                    LabeledContent(Strings.Pro.EarlyAdopter.settingsTitle) {
                        Image(systemName: "checkmark.seal.fill").foregroundColor(.rsGood)
                    }
                    Text(Strings.Pro.EarlyAdopter.settingsSubtitle).foregroundColor(.secondary)
                } else if viewModel.isPro {
                    LabeledContent(viewModel.ownedTitle) {
                        Image(systemName: "checkmark.seal.fill").foregroundColor(.rsGood)
                    }
                    Button(viewModel.manageTitle) { viewModel.openCustomerCenter() }
                } else {
                    LabeledContent(Strings.Pro.unlockTitle) {
                        Button(Strings.Pro.unlockTitle) { viewModel.showPaywall() }
                            .buttonStyle(.borderedProminent)
                    }
                    Text(viewModel.unlockSubtitle).foregroundColor(.secondary)
                }
            }

            if !viewModel.isEarlyAdopter {
                Section {
                    LabeledContent(Strings.Pro.restoreSubtitle) {
                        Button(Strings.Pro.restoreTitle) { viewModel.restore() }
                            .disabled(viewModel.isRestoring)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var about: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)

            Text("Dubloon")
                .font(.system(size: 20, weight: .bold))

            if let version = viewModel.versionText {
                Text(version)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Text(Strings.Settings.builtInSwitzerlandDesc)
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                Button(Strings.Settings.privacyPolicy) { viewModel.openPrivacyPolicy() }
                Button(Strings.ReviewBanner.rate) { openExternally(ReviewBanner.writeReviewURL) }
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
    }
}
