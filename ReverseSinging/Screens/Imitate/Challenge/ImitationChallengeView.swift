//
//  ImitationChallengeView.swift
//  ReverseSinging
//
//  One sound: hear it, imitate it, get stamped
//

import DubScoring
import SwiftUI

struct ImitationChallengeView: View {

    @StateObject private var viewModel: ImitationChallengeViewModel
    @ObservedObject private var boothPreference = BoothCamPreference.shared
    @Environment(\.dismiss) private var dismiss

    init(sound: ImitationSound) {
        _viewModel = StateObject(wrappedValue: ImitationChallengeViewModel(sound: sound))
    }

    var body: some View {
        ZStack {
            Color.rsSurface0
                .ignoresSafeArea()

            VStack(spacing: 0) {
                EditorScreenHeader(title: viewModel.sound.name, onBack: { dismiss() }) {
                    EditorToolbarButton(
                        icon: boothPreference.isEnabled ? "video.fill" : "video.slash",
                        label: Strings.Booth.settingsTitle
                    ) {
                        viewModel.toggleBooth()
                    }
                    .disabled(viewModel.isBusy)
                }

                ImitationStage(viewModel: viewModel)
                    .padding(.horizontal, EditorMetrics.gutter)
                    .padding(.top, 12)

                controls
                    .padding(.horizontal, EditorMetrics.gutter)
                    .padding(.vertical, 16)
            }

            CountdownOverlay(value: viewModel.countdown)

            if let progress = viewModel.exportProgress {
                ProcessingIndicator(message: Strings.Imitate.rendering, progress: progress)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .hidesNavigationBar()
        .boothCamPrimer(isPresented: $viewModel.isBoothPrimerPresented) { viewModel.boothPrimerDidEnable() }
        .sheet(item: $viewModel.exportedURL) { url in
            DubShareSheet(url: url)
        }
        .alert(Strings.Main.Alert.errorTitle, isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button(Strings.Main.Alert.ok, role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert(Strings.Main.Alert.microphoneRequiredTitle, isPresented: $viewModel.showPermissionAlert) {
            Button(Strings.Main.Alert.settings, action: AppSettings.open)
            Button(Strings.Main.Alert.cancel, role: .cancel) {}
        } message: {
            Text(Strings.Main.Alert.microphoneRequiredMessage)
        }
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
        .animation(.rsSpring, value: viewModel.phase)
        .animation(.rsSpring, value: viewModel.exportProgress != nil)
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 16) {
            referenceRow

            if viewModel.phase == .result, let score = viewModel.score {
                ImitationScoreParts(score: score)
                    .transition(.opacity)
            } else {
                Text(hint)
                    .font(.rsBodySmall)
                    .foregroundColor(viewModel.phase == .recording ? .rsRecord : .rsTextSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 40)
            }

            HStack(alignment: .center) {
                sideButton(
                    icon: viewModel.playingClip == .take ? "stop.fill" : "play.fill",
                    label: Strings.Imitate.playMine,
                    isVisible: viewModel.phase == .result
                ) { viewModel.playTake() }

                Spacer()

                VStack(spacing: 6) {
                    ImitationRecordButton(
                        isRecording: viewModel.phase == .recording,
                        isCountingIn: viewModel.phase == .countingIn,
                        elapsed: min(1, viewModel.recordingElapsed / viewModel.maximumTakeDuration),
                        level: viewModel.level,
                        isEnabled: viewModel.phase != .scoring && viewModel.exportProgress == nil
                    ) {
                        viewModel.toggleRecording()
                    }

                    Text(recordLabel)
                        .font(.rsCaption)
                        .foregroundColor(.rsTextSecondary)
                }

                Spacer()

                sideButton(
                    icon: "film",
                    label: Strings.Imitate.makeVideo,
                    isVisible: viewModel.phase == .result
                ) { viewModel.makeVideo() }
            }
        }
    }

    private var referenceRow: some View {
        Button { viewModel.playReference() } label: {
            HStack(spacing: 12) {
                Image(systemName: viewModel.playingClip == .reference ? "stop.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.rsTextPrimary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.rsSurface3))

                VStack(alignment: .leading, spacing: 2) {
                    Text(Strings.Imitate.listen)
                        .font(.rsButtonSmall)
                        .foregroundColor(.rsTextPrimary)
                    Text(String(format: "%.1fs", viewModel.sound.duration))
                        .font(.rsTimecodeSmall)
                        .foregroundColor(.rsTextTertiary)
                }

                SoundWaveBars(
                    bars: viewModel.referenceBars,
                    progress: viewModel.playingClip == .reference ? viewModel.playbackProgress : nil
                )
                .frame(height: 36)
            }
            .padding(10)
            .editorPanel(.rsSurface1)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(viewModel.isBusy)
    }

    private func sideButton(icon: String, label: String, isVisible: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.rsTextPrimary)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(Color.rsSurface2))
                    .overlay(Circle().strokeBorder(Color.rsStroke, lineWidth: EditorMetrics.hairline))
                Text(label)
                    .font(.rsCaption)
                    .foregroundColor(.rsTextSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 90)
        }
        .buttonStyle(ScaleButtonStyle())
        .opacity(isVisible ? 1 : 0)
        .disabled(!isVisible || viewModel.isBusy)
    }

    private var hint: String {
        switch viewModel.phase {
        case .recording: return Strings.Imitate.recordingHint
        case .scoring: return Strings.Imitate.scoring
        default: return Strings.Imitate.instruction
        }
    }

    private var recordLabel: String {
        switch viewModel.phase {
        case .recording, .countingIn: return Strings.Imitate.stop
        case .result: return Strings.Imitate.tryAgain
        default: return Strings.Imitate.record
        }
    }
}
