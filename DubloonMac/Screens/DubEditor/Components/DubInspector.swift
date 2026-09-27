//
//  DubInspector.swift
//  DubloonMac
//
//  The selected line, the take on it, the scene's standing, the camera and the export
//

import SwiftUI
import DubAudio
import DubScoring

struct DubInspector: View {
    @ObservedObject var viewModel: DubEditorViewModel
    @ObservedObject private var scoring = DubScoringPreference.shared
    @ObservedObject private var booth = BoothCamPreference.shared
    @ObservedObject private var headphones = HeadphoneMonitor.shared

    private var session: DubSessionViewModel { viewModel.session }
    private var pack: DubPack { viewModel.pack }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let line = session.currentLine {
                    lineSection(line)
                    takeSection(line)
                }

                sceneSection

                recordingSection

                exportSection

                if pack.hasAttribution {
                    sourceSection
                }
            }
        }
        .background(Color.rsSurface1)
        .onAppear { headphones.refresh() }
    }

    // MARK: - Line

    private func lineSection(_ line: DubLine) -> some View {
        ProInspectorSection(title: MacStrings.Panel.line + String(format: " %03d", line.index)) {
            DubCharacterPlate(
                character: line.character,
                color: DubCharacterStyle.color(for: line.character, in: pack.characters),
                isProminent: true
            )

            Text(line.caption)
                .font(.rsBodyMedium)
                .foregroundColor(.rsTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            ProInspectorRow(label: MacStrings.Panel.start, value: line.startTime.proTimecode)
            ProInspectorRow(label: MacStrings.Panel.duration, value: line.duration.proShortTime)
            ProInspectorRow(
                label: Strings.Dub.yourTake,
                value: session.isRecorded(line) ? Strings.Dub.slateLines : MacStrings.Panel.notDubbed,
                valueColor: session.isRecorded(line) ? .rsGood : .rsTextTertiary
            )
        }
    }

    @ViewBuilder
    private func takeSection(_ line: DubLine) -> some View {
        if scoring.isEnabled, let score = session.score(for: line) {
            ProInspectorSection(title: Strings.Dub.Score.lineTitle) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(Int(score.overall.rounded()))")
                        .font(.system(size: 34, weight: .semibold, design: .monospaced))
                        .foregroundColor(score.grade.color)
                    Text(score.grade.title)
                        .font(.rsCaption)
                        .foregroundColor(.rsTextSecondary)
                }
                DubScoreBar(label: Strings.Dub.Score.timing, value: score.timing, tint: score.grade.color)
                DubScoreBar(label: Strings.Dub.Score.pacing, value: score.pacing, tint: score.grade.color)
                DubScoreBar(label: Strings.Dub.Score.delivery, value: score.delivery, tint: score.grade.color)
            }
        }
    }

    // MARK: - Scene

    private var sceneSection: some View {
        ProInspectorSection(title: MacStrings.Panel.scene) {
            ProInspectorRow(label: Strings.Dub.slateLines, value: "\(session.recordedCount)/\(pack.lines.count)")
            ProInspectorRow(label: Strings.Dub.slateDuration, value: pack.duration.proTimecode)
            ProInspectorRow(label: Strings.Dub.slateCast, value: String(format: "%02d", pack.characters.count))

            DubProgressBar(recorded: session.recordedCount, total: pack.lines.count)

            Toggle(Strings.Dub.Score.settingTitle, isOn: $scoring.isEnabled)
                .toggleStyle(.switch)
                .controlSize(.small)
                .font(.rsMeta)

            if scoring.isEnabled {
                DubSceneScorePanel(score: session.sceneScore) { slug in
                    pack.lines.first { $0.slug == slug }
                }
            }

            if viewModel.detail.videoNeedsReimport {
                Label(Strings.Dub.videoNeedsReimport, systemImage: "exclamationmark.triangle.fill")
                    .font(.rsCaptionSmall)
                    .foregroundColor(.rsCaution)
            }
        }
    }

    // MARK: - Recording

    private var recordingSection: some View {
        ProInspectorSection(title: MacStrings.Settings.recording) {
            Toggle(isOn: Binding(
                get: { booth.isEnabled },
                set: { wants in if wants != booth.isEnabled { viewModel.record.toggleBooth() } }
            )) {
                Text(Strings.Booth.settingsTitle).font(.rsMeta)
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .disabled(viewModel.record.isRecording || viewModel.mode != .line)

            if booth.isEnabled {
                Toggle(isOn: $booth.mirrorsPreview) {
                    Text(Strings.Booth.mirrorTitle).font(.rsMeta)
                }
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            Toggle(isOn: $headphones.isEnabled) {
                Text(Strings.Settings.headphoneMonitor).font(.rsMeta)
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .disabled(!headphones.isHeadphonesConnected)
            .help(headphones.isHeadphonesConnected
                  ? Strings.Settings.headphoneMonitorDesc
                  : Strings.Settings.headphoneMonitorUnavailable)
        }
    }

    // MARK: - Export

    private var exportSection: some View {
        ProInspectorSection(title: Strings.Booth.exportTitle) {
            Button {
                viewModel.beginExport()
            } label: {
                Label(MacStrings.Menu.export, systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!session.hasAnyTake || viewModel.detail.isExporting)

            if let line = session.currentLine {
                Button {
                    viewModel.beginExport(line: line)
                } label: {
                    Label(Strings.Booth.shareLine, systemImage: "text.line.first.and.arrowtriangle.forward")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .disabled(!session.isRecorded(line) || viewModel.detail.isExporting)
            }

            if !session.hasAnyTake {
                Text(Strings.Dub.noTakesYet)
                    .font(.rsCaptionSmall)
                    .foregroundColor(.rsTextTertiary)
            }
        }
    }

    private var sourceSection: some View {
        ProInspectorSection(title: Strings.Dub.attribution) {
            if let source = pack.source {
                if let link = pack.sourceLink {
                    Link(source, destination: link).font(.rsMeta)
                } else {
                    Text(source).font(.rsMeta).foregroundColor(.rsTextSecondary)
                }
            }
            if let rights = pack.rightsLabel {
                if let url = pack.rightsURL {
                    Link(rights, destination: url).font(.rsCaptionSmall)
                } else {
                    Text(rights).font(.rsCaptionSmall).foregroundColor(.rsTextTertiary)
                }
            }
        }
    }
}
