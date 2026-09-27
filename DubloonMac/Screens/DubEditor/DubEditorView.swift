//
//  DubEditorView.swift
//  DubloonMac
//
//  A dub pack as an editing project: lines browser, viewer, timeline and inspector
//

import SwiftUI
import TipKit

struct DubEditorView: View {
    @StateObject private var viewModel: DubEditorViewModel
    @ObservedObject private var workspace: MacWorkspaceViewModel
    @ObservedObject private var scoring = DubScoringPreference.shared
    @ObservedObject private var booth = BoothCamPreference.shared

    @AppStorage("mac.dub.browserWidth") private var browserWidth: Double = 360
    @AppStorage("mac.dub.timelineHeight") private var timelineHeight: Double = 220

    init(pack: DubPack, library: DubPackLibrary, workspace: MacWorkspaceViewModel) {
        _viewModel = StateObject(wrappedValue: DubEditorViewModel(pack: pack, library: library))
        self.workspace = workspace
    }

    private var session: DubSessionViewModel { viewModel.session }
    private var record: DubRecordViewModel { viewModel.record }
    private var detail: DubPackDetailViewModel { viewModel.detail }

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Gives way before the viewer does when the window is narrow.
                    DubLinesBrowser(viewModel: viewModel)
                        .frame(width: ProPane.width(browserWidth, of: geometry.size.width, leaving: 420, minimum: 240))

                    ProResizeHandle(direction: .horizontal, value: $browserWidth, range: 260...600)

                    DubViewerPanel(viewModel: viewModel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                }
            }
            .frame(maxHeight: .infinity)

            ProResizeHandle(direction: .vertical, value: $timelineHeight, range: 140...520, inverted: true)

            DubTimelinePanel(viewModel: viewModel, player: session.scenePlayer)
                .frame(height: CGFloat(timelineHeight))
                .clipped()
        }
        .background(Color.rsSurface0)
        .proInspector(isPresented: workspace.showsInspector) {
            DubInspector(viewModel: viewModel)
        }
        .toolbar { toolbar }
        .navigationSubtitle(String(format: "%d/%d %@", session.recordedCount, viewModel.pack.lines.count, Strings.Dub.slateLines))
        .publishesTransport(transport, to: workspace)
        // The bay's own bookkeeping, which the iPhone's record screen does in its body. Kept
        // in the view, one line each, for the reason given there: a Combine sink would fire
        // before the view update and reorder the AV scheduling.
        .onChange(of: session.currentLineIndex) { _, _ in record.lineDidChange() }
        .onChange(of: session.isPreviewingReference) { _, isPreviewing in
            if viewModel.mode == .line { record.previewDidChange(isPreviewing: isPreviewing) }
        }
        .onChange(of: record.recordingAnchor) { _, anchor in record.recordingAnchorDidChange(anchor) }
        .onChange(of: record.isRecording) { _, isRecording in record.recordingDidChange(isRecording: isRecording) }
        .onChange(of: booth.isEnabled, initial: true) { _, isOn in record.boothPreferenceDidChange(isOn: isOn) }
        .onAppear {
            viewModel.onAppear()
            #if DEBUG
            MacE2EProbe.shared.dubEditor = viewModel
            #endif
        }
        .onDisappear { viewModel.onDisappear() }
        .task { await record.startBoothIfEnabled() }
        .task { await detail.checkVideo() }
        .task(id: scoring.isEnabled) { await detail.scoringDidChange() }
        // Export: options, then the notice, then the render and the save panel.
        .overlay {
            if detail.showExportOptions {
                DubExportOptionsModal(
                    pack: viewModel.pack,
                    line: detail.exportOptionsLine,
                    hasBoothFootage: session.hasAnyBoothTake,
                    runtime: { detail.runtime(of: $0) },
                    onExport: { cut, frame, includesBooth in
                        detail.configureExport(cut: cut, frame: frame, includesBooth: includesBooth)
                    },
                    onCancel: { detail.cancelExportOptions() }
                )
            }
        }
        .overlay {
            if detail.isExporting {
                ProcessingIndicator(message: detail.exportStage.message, progress: detail.exportProgress)
                    .transition(.opacity)
            }
        }
        .animation(.rsSmooth, value: detail.showExportOptions)
        .animation(.rsSpring, value: detail.isExporting)
        .dubShareNotice(isPresented: Binding(
            get: { detail.showShareNotice },
            set: { detail.showShareNotice = $0 }
        ), pack: viewModel.pack) {
            detail.confirmExport()
        }
        .sheet(item: Binding(get: { detail.exportedURL }, set: { detail.exportedURL = $0 })) { url in
            DubShareSheet(url: url)
        }
        .boothCamPrimer(isPresented: Binding(
            get: { record.isBoothPrimerPresented },
            set: { record.isBoothPrimerPresented = $0 }
        )) {
            record.boothPrimerDidEnable()
        }
        .alert(Strings.Main.Alert.microphoneRequiredTitle, isPresented: Binding(
            get: { record.showPermissionAlert },
            set: { record.showPermissionAlert = $0 }
        )) {
            Button(Strings.Main.Alert.settings, action: AppSettings.open)
            Button(Strings.Main.Alert.cancel, role: .cancel) {}
        } message: {
            Text(Strings.Main.Alert.microphoneRequiredMessage)
        }
        .alert(Strings.Main.Alert.errorTitle, isPresented: .init(
            get: { session.errorMessage != nil },
            set: { if !$0 { session.errorMessage = nil } }
        )) {
            Button(Strings.Main.Alert.ok, role: .cancel) { session.errorMessage = nil }
        } message: {
            Text(session.errorMessage ?? "")
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            DubDashboard(viewModel: viewModel, player: session.scenePlayer)
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                record.toggleBooth()
            } label: {
                Label(Strings.Booth.settingsTitle, systemImage: booth.isEnabled ? "video.fill" : "video.slash")
            }
            .disabled(record.isRecording || viewModel.mode != .line)
            .help(booth.isEnabled ? Strings.Booth.turnOff : Strings.Booth.turnOn)

            Toggle(isOn: $scoring.isEnabled) {
                Label(Strings.Dub.Score.settingTitle, systemImage: "chart.bar.fill")
            }
            .help(Strings.Dub.Score.settingDetail)

            Button {
                viewModel.beginExport()
            } label: {
                Label(Strings.Dub.export, systemImage: "square.and.arrow.up")
            }
            .disabled(!session.hasAnyTake || detail.isExporting)
            .help(Strings.Dub.export)

            Button {
                workspace.showsInspector.toggle()
            } label: {
                Label(MacStrings.Panel.inspector, systemImage: "sidebar.trailing")
            }
            .help(workspace.showsInspector ? MacStrings.Menu.hideInspector : MacStrings.Menu.showInspector)
        }
    }

    private var transport: MacTransport {
        let model = viewModel
        let bay = record
        let isLine = model.mode == .line
        let isRecording = bay.isRecording
        var canPlayTake = false
        if let line = session.currentLine { canPlayTake = bay.canPlayTake(of: line) }

        var transport = MacTransport()
        transport.togglePlay = { model.togglePlay() }
        transport.toggleRecord = { model.toggleRecord() }
        transport.isRecording = isRecording
        if isLine && !isRecording { transport.listen = { bay.toggleReferencePreview() } }
        if isLine && canPlayTake { transport.playTake = { bay.playCurrentTake() } }
        if !isRecording {
            transport.previous = { model.goToPrevious() }
            transport.next = { model.goToNext() }
        }
        if session.hasAnyTake { transport.export = { model.beginExport() } }
        return transport
    }
}

// MARK: - Dashboard

/// The toolbar's LCD for the editor. Watches the scene player itself: it ticks many times a
/// second, and only this and the timeline need every tick.
private struct DubDashboard: View {
    @ObservedObject var viewModel: DubEditorViewModel
    @ObservedObject var player: DubPlayer

    var body: some View {
        ProDashboard(
            lamp: viewModel.lamp,
            timecode: viewModel.playheadTime.proTimecode,
            detail: viewModel.lineReadout,
            level: viewModel.record.isRecording ? viewModel.record.recordingLevel : nil
        )
    }
}
