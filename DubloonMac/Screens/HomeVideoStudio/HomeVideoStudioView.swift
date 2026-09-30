//
//  HomeVideoStudioView.swift
//  DubloonMac
//
//  Home Video Dub: a clip from Photos or Finder in the viewer, its sound under it, a voice
//  recorded over it, and the finished video to share
//

import PhotosUI
import SwiftUI

struct HomeVideoStudioView: View {
    @ObservedObject var workspace: MacWorkspaceViewModel
    @StateObject private var viewModel = HomeVideoStudioViewModel()

    var body: some View {
        HomeVideoStagePane(viewModel: viewModel, dub: viewModel.dub)
            .background(Color.rsSurface0)
            .proInspector(isPresented: workspace.showsInspector) {
                HomeVideoInspector(dub: viewModel.dub)
            }
            .toolbar { toolbar }
            .navigationSubtitle(viewModel.durationText ?? "")
            .publishesTransport(transport)
            .onAppear {
                viewModel.onAppear()
                #if DEBUG
                MacE2EProbe.shared.homeVideo = viewModel
                #endif
            }
            .onDisappear { viewModel.onDisappear() }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            ProDashboard(
                lamp: viewModel.lamp,
                timecode: viewModel.timecode,
                detail: viewModel.durationText,
                level: viewModel.dub.phase == .recording ? viewModel.dub.level : nil
            )
        }

        ToolbarItem(placement: .primaryAction) {
            MacHelpButton(topic: .homeVideo)
        }

        ToolbarItemGroup(placement: .primaryAction) {
            HomeVideoChooseMenu(viewModel: viewModel)

            Button {
                viewModel.dub.share()
            } label: {
                Label(Strings.HomeVideo.share, systemImage: "square.and.arrow.up")
            }
            .disabled(viewModel.dub.phase != .review)
            .help(Strings.HomeVideo.share)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) { workspace.showsInspector.toggle() }
            } label: {
                Label(MacStrings.Panel.inspector, systemImage: "sidebar.trailing")
            }
            .help(workspace.showsInspector ? MacStrings.Menu.hideInspector : MacStrings.Menu.showInspector)
        }
    }

    private var transport: MacTransport {
        var transport = MacTransport()
        let workspace = workspace
        transport.toggleInspector = { withAnimation(.easeInOut(duration: 0.2)) { workspace.showsInspector.toggle() } }
        transport.isInspectorShown = workspace.showsInspector
        let dub = viewModel.dub
        transport.isRecording = dub.phase == .recording
        if viewModel.canPlay { transport.togglePlay = { dub.togglePlayback() } }
        if viewModel.canRecord { transport.toggleRecord = { dub.toggleRecording() } }
        if dub.phase == .review { transport.export = { dub.share() } }
        return transport
    }
}

// MARK: - Choose

/// Photos or a file: the two places a home video lives on a Mac.
struct HomeVideoChooseMenu: View {
    @ObservedObject var viewModel: HomeVideoStudioViewModel

    var body: some View {
        Menu {
            Button(MacStrings.HomeVideo.fromPhotos) { viewModel.choosePhoto() }
            Button(MacStrings.HomeVideo.fromFile) { viewModel.chooseFile() }
        } label: {
            Label(viewModel.dub.hasVideo ? Strings.HomeVideo.change : Strings.HomeVideo.choose,
                  systemImage: "photo.on.rectangle")
        }
        .disabled(viewModel.dub.isBusy)
        .help(viewModel.dub.hasVideo ? Strings.HomeVideo.change : Strings.HomeVideo.choose)
    }
}

// MARK: - Stage

/// The viewer over the clip's sound, and the transport under both.
private struct HomeVideoStagePane: View {
    @ObservedObject var viewModel: HomeVideoStudioViewModel
    @ObservedObject var dub: HomeVideoDubViewModel

    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            ProPanelHeader(title: MacStrings.Panel.viewer, subtitle: dub.source?.wasTrimmed == true ? Strings.HomeVideo.trimmed : nil) {
                HStack(spacing: 8) {
                    if dub.phase == .recording {
                        Label(Strings.Main.State.recording, systemImage: "record.circle")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.rsRecord)
                    }
                }
            }

            ZStack {
                Color.proViewer

                if dub.hasVideo {
                    picture
                } else {
                    emptyPicture
                }

                CountdownOverlay(value: dub.countdown)

                if isDropTargeted {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.accentColor, lineWidth: 2)
                        .padding(10)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 220, maxHeight: .infinity)
            .clipped()
            .dropDestination(for: URL.self) { urls, _ in
                viewModel.handleDrop(urls)
            } isTargeted: { isDropTargeted = $0 }

            waveform

            transport
        }
        .photosPicker(
            isPresented: $dub.isPickerPresented,
            selection: $dub.pickerItem,
            matching: .videos,
            preferredItemEncoding: .current
        )
        .fileImporter(
            isPresented: $viewModel.isFileImporterPresented,
            allowedContentTypes: HomeVideoStudioViewModel.videoTypes,
            allowsMultipleSelection: false
        ) { result in
            viewModel.handleFileImport(result)
        }
        .macProgressSheet(
            isPresented: dub.phase == .mixing || (dub.phase == .importing && dub.hasVideo),
            image: "film-reel",
            title: GameMode.homeVideo.title,
            message: dub.phase == .mixing ? Strings.HomeVideo.mixing : Strings.HomeVideo.importing,
            progress: nil
        )
        .sheet(item: $dub.sharedURL) { url in
            DubShareSheet(url: url)
        }
        .alert(Strings.Main.Alert.errorTitle, isPresented: .init(
            get: { dub.errorMessage != nil },
            set: { if !$0 { dub.errorMessage = nil } }
        )) {
            Button(Strings.Main.Alert.ok, role: .cancel) { dub.errorMessage = nil }
        } message: {
            Text(dub.errorMessage ?? "")
        }
        .microphonePrimer()
        .alert(Strings.Main.Alert.microphoneRequiredTitle, isPresented: $dub.showPermissionAlert) {
            Button(Strings.Main.Alert.settings, action: AppSettings.open)
            Button(Strings.Main.Alert.cancel, role: .cancel) {}
        } message: {
            Text(Strings.Main.Alert.microphoneRequiredMessage)
        }
        .animation(.rsSpring, value: dub.phase)
    }

    // MARK: - Picture

    private var picture: some View {
        ZStack(alignment: .bottom) {
            DubPlayerLayerView(player: dub.player)

            if !dub.isPlaying && viewModel.canPlay {
                Image(systemName: "play.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(Circle().fill(Color.black.opacity(0.45)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
            }

            GeometryReader { proxy in
                Rectangle()
                    .fill(dub.phase == .recording ? Color.rsRecord : Color.rsTextPrimary.opacity(0.8))
                    .frame(width: proxy.size.width * dub.playhead, height: 3)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .allowsHitTesting(false)
        }
        .background(Color.black)
        .overlay(
            Rectangle()
                .strokeBorder(dub.phase == .recording ? Color.rsRecord : .clear, lineWidth: 2)
        )
        .padding(18)
        .contentShape(Rectangle())
        .onTapGesture { dub.togglePlayback() }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(dub.isPlaying ? Strings.HomeVideo.pause : Strings.HomeVideo.play)
    }

    /// The viewer before anything is loaded is where a clip goes: a click opens Photos or a
    /// file, and a file can be dropped straight on it.
    private var emptyPicture: some View {
        VStack(spacing: 14) {
            if dub.phase == .importing {
                ProgressView()
            } else {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundColor(.rsTextPrimary)
            }

            Text(dub.phase == .importing ? Strings.HomeVideo.importing : Strings.HomeVideo.choose)
                .font(.rsButtonMedium)
                .foregroundColor(.rsTextPrimary)

            Text(MacStrings.HomeVideo.limit)
                .font(.rsCaption)
                .foregroundColor(.rsTextTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            HStack(spacing: 10) {
                Button(MacStrings.HomeVideo.fromPhotos) { viewModel.choosePhoto() }
                    .platformProminentButton()
                Button(MacStrings.HomeVideo.fromFile) { viewModel.chooseFile() }
            }
            .controlSize(.large)
            .disabled(dub.phase == .importing)
            .padding(.top, 4)

            Text(MacStrings.HomeVideo.dropHint)
                .font(.rsCaption)
                .foregroundColor(.rsTextTertiary)
        }
        .padding(28)
        .frame(maxWidth: 560, maxHeight: 360)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.rsSurface1))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.rsStroke, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
        )
        .padding(24)
    }

    // MARK: - Waveform

    /// The clip's own sound, with the take laid over it once there is one: where the bark or the
    /// laugh is, so the voice can land on it.
    private var waveform: some View {
        VStack(spacing: 0) {
            ProPanelHeader(title: MacStrings.Panel.sound)

            DubWaveformView(
                samples: dub.originalSamples.isEmpty ? Array(repeating: 0, count: 120) : dub.originalSamples,
                overlay: dub.takeSamples.isEmpty ? nil : dub.takeSamples,
                progress: dub.hasVideo ? dub.playhead : nil,
                height: 64
            )
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .opacity(dub.hasVideo ? 1 : 0.5)
            .accessibilityHidden(true)
        }
        .background(Color.rsSurface1)
        .overlay(alignment: .top) { EditorRule() }
    }

    // MARK: - Transport

    private var transport: some View {
        HStack(spacing: 10) {
            Text(viewModel.hint)
                .font(.rsCaptionSmall)
                .foregroundColor(dub.phase == .recording ? .rsRecord : .rsTextTertiary)
                .lineLimit(2)
                .frame(minWidth: 0, maxWidth: 260, alignment: .leading)
                .layoutPriority(-1)

            Spacer()

            ProTransportButton(
                icon: dub.isPlaying ? "pause.fill" : "play.fill",
                label: dub.isPlaying ? Strings.HomeVideo.pause : Strings.HomeVideo.play,
                isActive: dub.isPlaying
            ) {
                dub.togglePlayback()
            }
            .disabled(!viewModel.canPlay)

            ProRecordButton(
                isRecording: dub.phase == .recording,
                isCountingIn: dub.phase == .countingIn,
                level: dub.level,
                size: 38,
                label: viewModel.recordLabel
            ) {
                dub.toggleRecording()
            }
            .disabled(!viewModel.canRecord)
            .padding(.horizontal, 6)

            ProTransportButton(icon: "square.and.arrow.up", label: Strings.HomeVideo.share) {
                dub.share()
            }
            .disabled(dub.phase != .review)

            Spacer()

            Color.clear.frame(minWidth: 0, maxWidth: 260).layoutPriority(-1)
        }
        .padding(.horizontal, 14)
        .frame(height: 56)
        .background(Color.rsSurface2)
        .overlay(alignment: .top) { EditorRule() }
    }
}
