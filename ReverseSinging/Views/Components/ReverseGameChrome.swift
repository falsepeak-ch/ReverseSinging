//
//  ReverseGameChrome.swift
//  ReverseSinging
//
//  The frame both reverse-singing skins hang inside
//

import SwiftUI

/// `MainViewSimple` and `MainViewPremium` are two presentations of the same game, so they
/// share everything that is not the transport itself: the mic-denied state, the header,
/// and the sheets and alerts driven by the view model. Only the middle of the screen
/// differs between them, and only that lives in each skin.

// MARK: - Empty State

/// Shown in place of the transport when the microphone has been refused.
struct MicrophonePermissionEmptyState: View {
    let onOpenSettings: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image("microphone")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 160, height: 160)
                .scaleIn(delay: 0.1)

            VStack(spacing: 16) {
                Text(Strings.Main.EmptyState.title)
                    .font(.rsHeadingMedium)
                    .foregroundColor(Color.rsTextAdaptive(for: colorScheme))
                    .multilineTextAlignment(.center)

                Text(Strings.Main.EmptyState.message)
                    .font(.rsBodyMedium)
                    .foregroundColor(Color.rsSecondaryTextAdaptive(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 24)
            }
            .fadeIn(delay: 0.2)

            BigButton(
                title: Strings.Main.EmptyState.button,
                icon: "gearshape.fill",
                color: .rsTurquoise,
                action: onOpenSettings,
                style: .primary
            )
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .fadeIn(delay: 0.3)

            Spacer()
        }
    }
}

// MARK: - Header

/// Title, back, archive and settings — pinned above whatever the skin scrolls beneath it.
struct ReverseGameHeader: View {
    @ObservedObject var viewModel: AudioViewModel
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            EditorScreenHeader(title: GameMode.reverse.title, onBack: onBack) {
                EditorToolbarButton(icon: "archivebox", label: Strings.Session.archiveTitle) {
                    viewModel.showSessionList = true
                }
                EditorToolbarButton(icon: "slider.horizontal.3", label: Strings.Settings.title) {
                    viewModel.showSettings = true
                }
            }

            Spacer()
        }
        .ignoresSafeArea(edges: .top)
    }
}

// MARK: - Sheets & Alerts

extension View {

    /// The archive and settings sheets, the permission and error alerts, and the screen
    /// bookkeeping every reverse-singing skin needs on appear.
    func reverseGameChrome(viewModel: AudioViewModel, screenName: String) -> some View {
        self
            .onAppear {
                viewModel.checkPermissionStatus()
                AnalyticsManager.shared.trackScreenViewed(screenName: screenName)
            }
            .sheet(isPresented: Binding(
                get: { viewModel.showSessionList },
                set: { viewModel.showSessionList = $0 }
            )) {
                SessionListView(viewModel: viewModel)
            }
            .sheet(isPresented: Binding(
                get: { viewModel.showSettings },
                set: { viewModel.showSettings = $0 }
            )) {
                SettingsView(viewModel: viewModel, scope: .reverseSinging)
            }
            .alert(Strings.Main.Alert.microphoneRequiredTitle, isPresented: Binding(
                get: { viewModel.showPermissionAlert },
                set: { viewModel.showPermissionAlert = $0 }
            )) {
                Button(Strings.Main.Alert.settings, action: AppSettings.open)
                Button(Strings.Main.Alert.cancel, role: .cancel) {}
            } message: {
                Text(Strings.Main.Alert.microphoneRequiredMessage)
            }
            .alert(Strings.Main.Alert.errorTitle, isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button(Strings.Main.Alert.ok, role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Settings

enum AppSettings {
    /// Opens this app's own page in the system Settings app.
    ///
    /// Nonisolated so it can be handed straight to a button as `AppSettings.open`; the hop
    /// to the main actor happens here rather than at every call site.
    nonisolated static func open() {
        Task { @MainActor in
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        }
    }
}
