//
//  ImitateStudioView.swift
//  DubloonMac
//
//  Sound Imitation as an analysis bench: a sound browser, the stage over a comparison of the
//  sound and the attempt, and an inspector with the verdict
//

import SwiftUI
import DubScoring

struct ImitateStudioView: View {
    @ObservedObject var workspace: MacWorkspaceViewModel
    @StateObject private var viewModel = ImitateStudioViewModel()
    @ObservedObject private var boothPreference = BoothCamPreference.shared

    @AppStorage("mac.imitate.browserWidth") private var browserWidth: Double = 340

    var body: some View {
        GeometryReader { geometry in
        HStack(spacing: 0) {
            ImitateSoundBrowser(viewModel: viewModel)
                .frame(width: ProPane.width(browserWidth, of: geometry.size.width, leaving: 420, minimum: 260))

            ProResizeHandle(direction: .horizontal, value: $browserWidth, range: 280...560)

            Group {
                if let challenge = viewModel.challenge {
                    ImitateStagePane(challenge: challenge)
                        .id(challenge.sound.id)
                } else {
                    EmptyWorkspaceView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        }
        .background(Color.rsSurface0)
        .proInspector(isPresented: workspace.showsInspector) {
            ImitateInspector(viewModel: viewModel)
        }
        .toolbar { toolbar }
        .navigationSubtitle(viewModel.selectedSound?.name ?? "")
        .publishesTransport(transport)
        .onAppear {
            viewModel.onAppear()
            #if DEBUG
            MacE2EProbe.shared.imitate = viewModel
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
                detail: viewModel.challenge?.score.map { "\(Int($0.overall.rounded()))  \($0.grade.badge)" },
                level: viewModel.challenge?.phase == .recording ? viewModel.challenge?.level : nil
            )
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                viewModel.challenge?.toggleBooth()
            } label: {
                Label(Strings.Booth.settingsTitle, systemImage: boothPreference.isEnabled ? "video.fill" : "video.slash")
            }
            .disabled(viewModel.challenge?.isBusy ?? true)
            .help(boothPreference.isEnabled ? Strings.Booth.turnOff : Strings.Booth.turnOn)

            Button {
                viewModel.challenge?.makeVideo()
            } label: {
                Label(Strings.Imitate.makeVideo, systemImage: "film")
            }
            .disabled(viewModel.challenge?.phase != .result || viewModel.challenge?.isBusy == true)
            .help(Strings.Imitate.makeVideo)

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
        guard let challenge = viewModel.challenge else { return transport }
        let isBusy = challenge.isBusy
        let phase = challenge.phase
        transport.isRecording = phase == .recording
        if !isBusy {
            let studio = viewModel
            transport.togglePlay = { challenge.playReference() }
            transport.listen = { challenge.playReference() }
            transport.previous = { studio.selectNeighbour(-1) }
            transport.next = { studio.selectNeighbour(1) }
        }
        if phase != .scoring { transport.toggleRecord = { challenge.toggleRecording() } }
        if phase == .result && !isBusy {
            transport.playTake = { challenge.playTake() }
            transport.export = { challenge.makeVideo() }
        }
        return transport
    }
}

// MARK: - Stage

/// The selected sound's stage above the comparison of the sound and the attempt, and the
/// transport under both.
private struct ImitateStagePane: View {
    @ObservedObject var challenge: ImitationChallengeViewModel

    @AppStorage("mac.imitate.compareHeight") private var compareHeight: Double = 230

    var body: some View {
        VStack(spacing: 0) {
            ProPanelHeader(title: MacStrings.Panel.viewer, subtitle: challenge.sound.name) {
                HStack(spacing: 8) {
                    Text(challenge.sound.category.title)
                        .editorLabelStyle(.rsTextTertiary)
                    if challenge.phase == .recording {
                        RecordingBadge(elapsed: challenge.recordingElapsed)
                    }
                }
            }

            ZStack {
                Color.proViewer

                ImitationStage(viewModel: challenge)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .frame(maxWidth: 900)
                    .padding(18)

                CountdownOverlay(value: challenge.countdown)
            }
            .frame(maxWidth: .infinity, minHeight: 180, maxHeight: .infinity)
            .clipped()

            ProResizeHandle(direction: .vertical, value: $compareHeight, range: 170...420, inverted: true)

            ImitateComparePanel(challenge: challenge)
                .frame(height: CGFloat(compareHeight))
                .clipped()

            transport
        }
        .macProgressSheet(
            isPresented: challenge.exportProgress != nil,
            image: "film-reel",
            title: Strings.Imitate.makeVideo,
            message: Strings.Imitate.rendering,
            progress: challenge.exportProgress
        )
        .animation(.rsSpring, value: challenge.phase)
        .animation(.rsSpring, value: challenge.exportProgress != nil)
        .boothCamPrimer(isPresented: $challenge.isBoothPrimerPresented) { challenge.boothPrimerDidEnable() }
        .sheet(item: $challenge.exportedURL) { url in
            DubShareSheet(url: url)
        }
        .alert(Strings.Main.Alert.errorTitle, isPresented: .init(
            get: { challenge.errorMessage != nil },
            set: { if !$0 { challenge.errorMessage = nil } }
        )) {
            Button(Strings.Main.Alert.ok, role: .cancel) { challenge.errorMessage = nil }
        } message: {
            Text(challenge.errorMessage ?? "")
        }
        .microphonePrimer()
        .alert(Strings.Main.Alert.microphoneRequiredTitle, isPresented: $challenge.showPermissionAlert) {
            Button(Strings.Main.Alert.settings, action: AppSettings.open)
            Button(Strings.Main.Alert.cancel, role: .cancel) {}
        } message: {
            Text(Strings.Main.Alert.microphoneRequiredMessage)
        }
    }

    private var transport: some View {
        HStack(spacing: 10) {
            Text(hint)
                .font(.rsCaptionSmall)
                .foregroundColor(challenge.phase == .recording ? .rsRecord : .rsTextTertiary)
                .lineLimit(2)
                .frame(minWidth: 0, maxWidth: 200, alignment: .leading)
                .layoutPriority(-1)

            Spacer()

            ProTransportButton(
                icon: challenge.playingClip == .reference ? "stop.fill" : "speaker.wave.2.fill",
                label: Strings.Imitate.listen,
                isActive: challenge.playingClip == .reference
            ) {
                challenge.playReference()
            }
            .disabled(challenge.isBusy)

            ProRecordButton(
                isRecording: challenge.phase == .recording,
                isCountingIn: challenge.phase == .countingIn,
                level: challenge.level,
                size: 38,
                label: challenge.phase == .recording ? Strings.Imitate.stop : Strings.Imitate.record
            ) {
                challenge.toggleRecording()
            }
            .disabled(challenge.phase == .scoring || challenge.exportProgress != nil)
            .padding(.horizontal, 6)

            ProTransportButton(
                icon: challenge.playingClip == .take ? "stop.fill" : "play.fill",
                label: Strings.Imitate.playMine,
                isActive: challenge.playingClip == .take
            ) {
                challenge.playTake()
            }
            .disabled(challenge.phase != .result || challenge.isBusy)

            Spacer()

            ProTransportButton(icon: "film", label: Strings.Imitate.makeVideo) {
                challenge.makeVideo()
            }
            .disabled(challenge.phase != .result || challenge.isBusy)
            .frame(minWidth: 0, maxWidth: 200, alignment: .trailing)
                .layoutPriority(-1)
        }
        .padding(.horizontal, 14)
        .frame(height: 56)
        .background(Color.rsSurface2)
        .overlay(alignment: .top) { EditorRule() }
    }

    private var hint: String {
        switch challenge.phase {
        case .recording: Strings.Imitate.recordingHint
        case .scoring: Strings.Imitate.scoring
        default: Strings.Imitate.instruction
        }
    }
}

// MARK: - Recording Badge

/// The red light and running time a recorder shows while it is rolling.
private struct RecordingBadge: View {
    let elapsed: TimeInterval
    @State private var isLit = true

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color.rsRecord)
                .frame(width: 7, height: 7)
                .opacity(isLit ? 1 : 0.25)
            Text(verbatim: "REC \(elapsed.proShortTime)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.rsRecord)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { isLit = false }
        }
    }
}
