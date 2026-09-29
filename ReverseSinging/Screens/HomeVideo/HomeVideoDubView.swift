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
                    if viewModel.hasVideo {
                        EditorToolbarButton(icon: "photo.on.rectangle", label: Strings.HomeVideo.change) {
                            viewModel.isPickerPresented = true
                        }
                        .disabled(viewModel.isBusy)
                    }
                }

                if viewModel.hasVideo {
                    studio
                } else {
                    ScrollView {
                        HomeVideoIntro(pickerItem: $viewModel.pickerItem, isImporting: viewModel.phase == .importing)
                            .padding(.horizontal, EditorMetrics.gutter)
                            .padding(.top, 16)
                            .padding(.bottom, 32)
                    }
                }
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

    private var studio: some View {
        VStack(spacing: 14) {
            picture

            if let source = viewModel.source, source.wasTrimmed {
                Text(Strings.HomeVideo.trimmed)
                    .font(.rsCaption)
                    .foregroundColor(.rsTextTertiary)
            }

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
        .disabled(viewModel.isBusy || viewModel.source?.hasSound == false)
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
                    isEnabled: viewModel.phase != .mixing && viewModel.phase != .importing
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
        case .recording: return Strings.HomeVideo.recordingHint
        case .review: return Strings.HomeVideo.reviewHint
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
