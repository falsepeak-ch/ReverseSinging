//
//  MacWelcomeView.swift
//  DubloonMac
//
//  "Welcome to Dubloon": the app icon, what's inside, and one Continue button, in the shape
//  every first-run window on the Mac takes
//

import SwiftUI

struct MacWelcomeView: View {
    @StateObject private var viewModel: MacWelcomeViewModel
    @Environment(\.scenePhase) private var scenePhase

    init(app: AppViewModel) {
        _viewModel = StateObject(wrappedValue: MacWelcomeViewModel(app: app))
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch viewModel.step {
                case .welcome: welcome
                case .microphone: microphone
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))

            buttons
        }
        .frame(width: 620, height: 580)
        .background(Color.rsSurface1)
        .onAppear {
            viewModel.onAppear()
            #if DEBUG
            MacE2EProbe.shared.welcome = viewModel
            #endif
        }
        .onChange(of: scenePhase) { _, phase in viewModel.scenePhaseDidChange(phase) }
    }

    // MARK: - Welcome

    private var welcome: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
                .padding(.top, 40)

            Text(Strings.Onboarding.welcomeTitle)
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(.rsTextPrimary)
                .padding(.top, 18)

            VStack(alignment: .leading, spacing: 22) {
                ForEach(viewModel.features) { mode in
                    featureRow(mode)
                }
            }
            .frame(maxWidth: 440, alignment: .leading)
            .padding(.top, 34)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 40)
    }

    private func featureRow(_ mode: GameMode) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Image(mode.image)
                .resizable()
                .scaledToFit()
                .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text(mode.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.rsTextPrimary)
                Text(mode.subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.rsTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Microphone

    private var microphone: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            ZStack {
                Circle()
                    .fill(Color.rsSurface2)
                    .frame(width: 120, height: 120)
                Image("studio-mic-boom")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 84, height: 84)
            }

            Text(Strings.Onboarding.microphoneTitle)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.rsTextPrimary)
                .padding(.top, 22)

            Text(Strings.Onboarding.microphoneMessage)
                .font(.system(size: 13))
                .foregroundColor(.rsTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 440)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)

            if viewModel.isDenied {
                Label(Strings.Main.Alert.microphoneRequiredTitle, systemImage: "mic.slash.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.rsCaution)
                    .padding(.top, 16)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Buttons

    private var buttons: some View {
        HStack(spacing: 12) {
            if viewModel.step == .microphone {
                Button(MacStrings.Welcome.notNow) { viewModel.skip() }
                    .controlSize(.large)
                    .keyboardShortcut(.cancelAction)
            }

            Spacer()

            HStack(spacing: 6) {
                Circle().fill(viewModel.step == .welcome ? Color.rsTextPrimary : Color.rsSurface3)
                Circle().fill(viewModel.step == .microphone ? Color.rsTextPrimary : Color.rsSurface3)
            }
            .frame(width: 22, height: 7)

            Spacer()

            Button(viewModel.primaryTitle) { viewModel.primaryAction() }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(Color.rsSurface2)
        .overlay(alignment: .top) { EditorRule() }
    }
}
