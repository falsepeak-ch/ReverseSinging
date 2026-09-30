//
//  ReverseStudioView.swift
//  DubloonMac
//
//  Reverse singing laid out as a recording studio: a monitor with the record key, four tracks,
//  and an inspector with the score and the knobs
//

import SwiftUI
import TipKit

struct ReverseStudioView: View {
    @StateObject private var viewModel: ReverseStudioViewModel
    @ObservedObject private var game: ReverseGameViewModel
    @ObservedObject private var workspace: MacWorkspaceViewModel

    @State private var isConfirmingNewSession = false
    @AppStorage("mac.reverse.tracksHeight") private var tracksHeight: Double = 360

    init(game: ReverseGameViewModel, workspace: MacWorkspaceViewModel, archived: AudioSession?) {
        _viewModel = StateObject(wrappedValue: ReverseStudioViewModel(game: game, archived: archived))
        self.game = game
        self.workspace = workspace
    }

    var body: some View {
        Group {
            if game.isMicrophoneDenied && !viewModel.isArchived {
                MicrophonePermissionEmptyState(onOpenSettings: AppSettings.open)
            } else {
                VStack(spacing: 0) {
                    monitor
                        .frame(maxHeight: .infinity)
                        .clipped()
                    ProResizeHandle(direction: .vertical, value: $tracksHeight, range: 220...560, inverted: true)
                    tracks
                        .frame(height: CGFloat(tracksHeight))
                }
            }
        }
        .background(Color.rsSurface0)
        .overlay { CountdownOverlay(value: game.countdown) }
        .overlay {
            if game.isReversing {
                ProcessingIndicator(message: Strings.Main.processingReversingAudio)
                    .transition(.opacity)
            }
        }
        .animation(.rsSpring, value: game.isReversing)
        .proInspector(isPresented: workspace.showsInspector) {
            ReverseInspector(viewModel: viewModel, workspace: workspace)
        }
        .toolbar { toolbar }
        .navigationSubtitle(viewModel.session?.name ?? "")
        .publishesTransport(transport)
        .task(id: viewModel.waveformKey) { await viewModel.loadWaveforms() }
        .onAppear {
            viewModel.onAppear()
            #if DEBUG
            MacE2EProbe.shared.reverse = viewModel
            #endif
        }
        .onDisappear { viewModel.onDisappear() }
        .alert(Strings.Main.Alert.startNewSessionTitle, isPresented: $isConfirmingNewSession) {
            Button(Strings.Main.Alert.cancel, role: .cancel) {}
            Button(Strings.Main.Alert.startNewSessionButton) { viewModel.newSession() }
        } message: {
            Text(Strings.Main.Alert.startNewSessionMessage)
        }
        .microphonePrimer()
        .alert(Strings.Main.Alert.microphoneRequiredTitle, isPresented: $game.showPermissionAlert) {
            Button(Strings.Main.Alert.settings, action: AppSettings.open)
            Button(Strings.Main.Alert.cancel, role: .cancel) {}
        } message: {
            Text(Strings.Main.Alert.microphoneRequiredMessage)
        }
        .alert(Strings.Main.Alert.errorTitle, isPresented: .init(
            get: { game.errorMessage != nil },
            set: { if !$0 { game.errorMessage = nil } }
        )) {
            Button(Strings.Main.Alert.ok, role: .cancel) { game.errorMessage = nil }
        } message: {
            Text(game.errorMessage ?? "")
        }
    }

    // MARK: - Monitor

    private var monitor: some View {
        VStack(spacing: 0) {
            ProPanelHeader(
                title: viewModel.isArchived ? Strings.Session.archiveTitle : MacStrings.Panel.viewer,
                subtitle: viewModel.session?.name
            )

            ZStack {
                Color.proViewer

                VStack(spacing: 18) {
                    WaveformView(
                        level: game.recordingLevel,
                        barCount: 96,
                        style: waveformStyle,
                        recordingDuration: nil
                    )
                    .frame(height: 110)
                    .frame(maxWidth: 900)
                    .opacity(viewModel.isArchived ? 0.3 : 1)

                    HStack(spacing: 22) {
                        if !viewModel.isArchived {
                            ProRecordButton(
                                isRecording: viewModel.isRecording,
                                isCountingIn: game.countdown != nil,
                                level: game.recordingLevel,
                                size: 58,
                                label: viewModel.recordTitle
                            ) {
                                viewModel.toggleRecord()
                            }
                            .disabled(viewModel.recordStep == .unavailable)
                            .opacity(viewModel.recordStep == .unavailable ? 0.35 : 1)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(viewModel.isArchived ? Strings.Session.archiveTitle : viewModel.recordTitle)
                                .font(.rsHeadingSmall)
                                .foregroundColor(viewModel.isRecording ? .rsRecord : .rsTextPrimary)

                            Text(viewModel.hint)
                                .font(.rsBodySmall)
                                .foregroundColor(.rsTextSecondary)
                        }
                        .frame(minWidth: 260, alignment: .leading)
                    }
                }
                .padding(28)
                .animation(.rsQuick, value: viewModel.recordStep == .unavailable)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var waveformStyle: WaveformView.WaveformStyle {
        switch game.appState.recordingState {
        case .recording: .recording
        case .playing: .playing
        default: .idle
        }
    }

    // MARK: - Tracks

    private var tracks: some View {
        VStack(spacing: 0) {
            ProPanelHeader(title: Strings.Dub.timeline)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(viewModel.lanes) { lane in
                        ReverseTrackLane(
                            lane: lane,
                            samples: lane.recording.flatMap { viewModel.waveforms[$0.id] } ?? [],
                            isPlaying: viewModel.isPlaying(lane),
                            progress: viewModel.progress(of: lane),
                            placeholder: viewModel.placeholder(for: lane),
                            isEnabled: !viewModel.isRecording
                        ) {
                            viewModel.toggle(lane)
                        }
                    }
                }
            }
            .background(Color.rsSurface0)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            ProDashboard(
                lamp: viewModel.lamp,
                timecode: viewModel.timecode,
                detail: viewModel.score.map { "\(ScoreCard.letterGrade(for: $0))  \(Int($0))%" },
                level: viewModel.isRecording ? game.recordingLevel : nil
            )
            .popoverTip(MacShortcutsTip(), arrowEdge: .top)
        }

        ToolbarItem(placement: .primaryAction) {
            MacHelpButton(topic: .reverse)
        }

        ToolbarItemGroup(placement: .primaryAction) {
            if !viewModel.isArchived {
                Button {
                    isConfirmingNewSession = true
                } label: {
                    Label(Strings.Main.newSession, systemImage: "plus.square.on.square")
                }
                .disabled(!viewModel.hasRecordings || viewModel.isRecording)
                .help(Strings.Main.newSession)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) { workspace.showsInspector.toggle() }
            } label: {
                Label(MacStrings.Panel.inspector, systemImage: "sidebar.trailing")
            }
            .help(workspace.showsInspector ? MacStrings.Menu.hideInspector : MacStrings.Menu.showInspector)
        }
    }

    private var transport: MacTransport {
        let model = viewModel
        var transport = MacTransport()
        let workspace = workspace
        transport.toggleInspector = { withAnimation(.easeInOut(duration: 0.2)) { workspace.showsInspector.toggle() } }
        transport.isInspectorShown = workspace.showsInspector
        transport.isRecording = model.isRecording
        if !model.isRecording { transport.togglePlay = { model.togglePlay() } }
        if model.recordStep != .unavailable { transport.toggleRecord = { model.toggleRecord() } }
        return transport
    }
}
