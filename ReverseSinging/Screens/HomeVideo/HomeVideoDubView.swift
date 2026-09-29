//
//  HomeVideoDubView.swift
//  ReverseSinging
//
//  Home Video Dub: pick a video, talk over it, share it
//

import PhotosUI
import SwiftUI

struct HomeVideoDubView: View {

    @StateObject private var viewModel = HomeVideoDubViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.rsSurface0
                .ignoresSafeArea()
                .filmGrain()

            VStack(spacing: 0) {
                EditorScreenHeader(title: GameMode.homeVideo.title, onBack: { dismiss() }) {
                    HStack(spacing: 10) {
                        HelpButton(topic: .homeVideo)

                        if viewModel.hasVideo {
                            EditorToolbarButton(icon: "photo.on.rectangle", label: Strings.HomeVideo.change) {
                                viewModel.isPickerPresented = true
                            }
                            .disabled(viewModel.isBusy)
                        }
                    }
                }

                studio
            }

            CountdownOverlay(value: viewModel.countdown)

            if viewModel.phase == .importing && viewModel.hasVideo {
                ProcessingIndicator(message: Strings.HomeVideo.importing)
                    .transition(.opacity)
            }
            if viewModel.phase == .mixing {
                ProcessingIndicator(message: Strings.HomeVideo.mixing)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .hidesNavigationBar()
        .photosPicker(
            isPresented: $viewModel.isPickerPresented,
            selection: $viewModel.pickerItem,
            matching: .videos,
            preferredItemEncoding: .current
        )
        .sheet(item: $viewModel.sharedURL) { url in
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
    }

    // MARK: - Studio

    /// The same screen before and after a video is picked, so the game opens on the thing it
    /// is rather than on an explanation of it. Until then the picture's slot is the picker.
    private var studio: some View {
        VStack(spacing: 14) {
            if viewModel.hasVideo {
                picture
            } else {
                emptyPicture
            }

            if let source = viewModel.source, source.wasTrimmed {
                Text(Strings.HomeVideo.trimmed)
                    .font(.rsCaption)
                    .foregroundColor(.rsTextTertiary)
            }

            waveform

            originalSoundToggle

            Spacer(minLength: 0)

            Text(hint)
                .font(.rsBodySmall)
                .foregroundColor(viewModel.phase == .recording ? .rsRecord : .rsTextSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 40)

            controls
        }
        .padding(.horizontal, EditorMetrics.gutter)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    private var picture: some View {
        ZStack(alignment: .bottom) {
            DubPlayerLayerView(player: viewModel.player)

            if !viewModel.isPlaying && (viewModel.phase == .ready || viewModel.phase == .review) {
                Image(systemName: "play.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(Circle().fill(Color.black.opacity(0.45)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
            }

            if viewModel.phase == .recording {
                recordingTag
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(10)
            }

            GeometryReader { proxy in
                Rectangle()
                    .fill(viewModel.phase == .recording ? Color.rsRecord : Color.rsTextPrimary.opacity(0.8))
                    .frame(width: proxy.size.width * viewModel.playhead, height: 3)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .allowsHitTesting(false)
        }
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: EditorMetrics.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: EditorMetrics.radius, style: .continuous)
                .strokeBorder(viewModel.phase == .recording ? Color.rsRecord : .rsStroke, lineWidth: EditorMetrics.hairline)
        )
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { viewModel.togglePlayback() }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(viewModel.isPlaying ? Strings.HomeVideo.pause : Strings.HomeVideo.play)
    }

    /// A plain button rather than a `PhotosPicker` with a label: the picker builds its label
    /// outside the main actor, and every colour and font in it was a concurrency warning. The
    /// screen's `.photosPicker` modifier is the one that opens.
    private var emptyPicture: some View {
        Button {
            viewModel.isPickerPresented = true
        } label: {
            VStack(spacing: 14) {
                if viewModel.phase == .importing {
                    ProgressView().tint(.rsTextPrimary)
                } else {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundColor(.rsTextPrimary)
                }
                Text(viewModel.phase == .importing ? Strings.HomeVideo.importing : Strings.HomeVideo.choose)
                    .font(.rsButtonMedium)
                    .foregroundColor(.rsTextPrimary)
                Text(Strings.HomeVideo.limit)
                    .font(.rsCaption)
                    .foregroundColor(.rsTextTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.rsSurface1)
            .clipShape(RoundedRectangle(cornerRadius: EditorMetrics.radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: EditorMetrics.radius, style: .continuous)
                    .strokeBorder(Color.rsStroke, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(viewModel.phase == .importing)
        .frame(maxHeight: .infinity)
    }

    /// The clip's own sound under the picture, with the take laid over it once there is one:
    /// where the bark or the laugh is, so the voice can land on it.
    private var waveform: some View {
        DubWaveformView(
            samples: viewModel.originalSamples.isEmpty ? Array(repeating: 0, count: 120) : viewModel.originalSamples,
            overlay: viewModel.takeSamples.isEmpty ? nil : viewModel.takeSamples,
            progress: viewModel.hasVideo ? viewModel.playhead : nil,
            height: 44
        )
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .editorPanel(.rsSurface1)
        .opacity(viewModel.hasVideo ? 1 : 0.5)
        .accessibilityHidden(true)
    }

    private var recordingTag: some View {
        HStack(spacing: 6) {
            Circle().fill(Color.rsRecord).frame(width: 8, height: 8)
            Text(Strings.Main.State.recording)
                .font(.rsLabelSmall)
                .textCase(.uppercase)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.black.opacity(0.55)))
    }

    private var originalSoundToggle: some View {
        Toggle(isOn: $viewModel.keepsOriginalSound) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Strings.HomeVideo.keepOriginal)
                    .font(.rsButtonSmall)
                    .foregroundColor(.rsTextPrimary)
                Text(viewModel.source?.hasSound == false ? Strings.HomeVideo.noOriginalSound : Strings.HomeVideo.keepOriginalDetail)
                    .font(.rsCaption)
                    .foregroundColor(.rsTextTertiary)
            }
        }
        .tint(.rsRecord)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .editorPanel(.rsSurface1)
        .disabled(viewModel.isBusy || !viewModel.hasVideo || viewModel.source?.hasSound == false)
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(alignment: .center) {
            Color.clear.frame(width: 90, height: 1)

            Spacer()

            VStack(spacing: 6) {
                ImitationRecordButton(
                    isRecording: viewModel.phase == .recording,
                    isCountingIn: viewModel.phase == .countingIn,
                    elapsed: viewModel.recordingProgress,
                    level: viewModel.level,
                    isEnabled: viewModel.hasVideo && viewModel.phase != .mixing && viewModel.phase != .importing
                ) {
                    viewModel.toggleRecording()
                }

                Text(recordLabel)
                    .font(.rsCaption)
                    .foregroundColor(.rsTextSecondary)
            }

            Spacer()

            Button { viewModel.share() } label: {
                VStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.rsTextPrimary)
                        .frame(width: 52, height: 52)
                        .background(Circle().fill(Color.rsSurface2))
                        .overlay(Circle().strokeBorder(Color.rsStroke, lineWidth: EditorMetrics.hairline))
                    Text(Strings.HomeVideo.share)
                        .font(.rsCaption)
                        .foregroundColor(.rsTextSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(width: 90)
            }
            .buttonStyle(ScaleButtonStyle())
            .opacity(viewModel.phase == .review ? 1 : 0)
            .disabled(viewModel.phase != .review)
        }
    }

    private var hint: String {
        switch viewModel.phase {
        case .recording:
            return viewModel.isMonitoring ? Strings.HomeVideo.recordingHintHeadphones : Strings.HomeVideo.recordingHint
        case .review: return Strings.HomeVideo.reviewHint
        case .empty, .importing: return Strings.HomeVideo.emptyHint
        default: return Strings.HomeVideo.readyHint
        }
    }

    private var recordLabel: String {
        switch viewModel.phase {
        case .recording, .countingIn: return Strings.HomeVideo.stop
        case .review: return Strings.HomeVideo.retake
        default: return Strings.HomeVideo.record
        }
    }
}

#Preview {
    NavigationStack {
        HomeVideoDubView()
    }
    .preferredColorScheme(.dark)
}
