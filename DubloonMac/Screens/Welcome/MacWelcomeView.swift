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

    init(app: AppViewModel) {
        _viewModel = StateObject(wrappedValue: MacWelcomeViewModel(app: app))
    }

    var body: some View {
        VStack(spacing: 0) {
            welcome
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            buttons
        }
        .frame(width: 620, height: 720)
        .background(Color.rsSurface1)
        .onAppear {
            viewModel.onAppear()
            #if DEBUG
            MacE2EProbe.shared.welcome = viewModel
            #endif
        }
        .onDisappear { viewModel.windowDidClose() }
        .sheet(isPresented: Binding(
            get: { viewModel.onboarding.isPaywallPresented },
            set: { viewModel.onboarding.isPaywallPresented = $0 }
        )) {
            ProPaywallView(source: "onboarding")
        }
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

            proNote
                .frame(maxWidth: 440, alignment: .leading)
                .padding(.top, 26)

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

    /// What Pro is for and what stays free, said before anyone meets a lock, as the iPhone's
    /// last onboarding page says it.
    private var proNote: some View {
        HStack(alignment: .top, spacing: 16) {
            Image("settings-unlock")
                .resizable()
                .scaledToFit()
                .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text(Strings.Onboarding.proTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.rsTextPrimary)
                Text(Strings.Onboarding.proMessage)
                    .font(.system(size: 12))
                    .foregroundColor(.rsTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.rsSurface2))
    }

    // MARK: - Buttons

    private var buttons: some View {
        HStack(spacing: 12) {
            Spacer()

            if viewModel.offersPro {
                Button(Strings.Onboarding.proSkip) { viewModel.skip() }
                    .controlSize(.large)
                    .keyboardShortcut(.cancelAction)
            }

            Button(viewModel.primaryTitle) { viewModel.primaryAction() }
                .controlSize(.large)
                .platformProminentButton()
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(Color.rsSurface2)
        .overlay(alignment: .top) { EditorRule() }
    }
}

// MARK: - Window

/// The welcome in a window of its own, in front of the library, the way Xcode and Final Cut
/// greet a first launch. It closes itself once onboarding is done, and never comes back.
struct MacWelcomeWindow: View {
    @ObservedObject var app: AppViewModel
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        MacWelcomeView(app: app)
            .preferredColorScheme(.dark)
            .onChange(of: app.hasCompletedOnboarding, initial: true) { _, isDone in
                if isDone { dismissWindow(id: MacWindowID.welcome) }
            }
    }
}
