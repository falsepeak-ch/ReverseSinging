//
//  DubLinesBrowser.swift
//  DubloonMac
//
//  The pack's lines as a browser list: number, speaker, caption, length and status
//

import SwiftUI
import DubScoring

struct DubLinesBrowser: View {
    @ObservedObject var viewModel: DubEditorViewModel

    private var session: DubSessionViewModel { viewModel.session }
    private var pack: DubPack { viewModel.pack }

    var body: some View {
        VStack(spacing: 0) {
            ProPanelHeader(
                title: Strings.Dub.lines,
                subtitle: String(format: "%02d", pack.lines.count)
            )

            Table(pack.lines, selection: selection) {
                TableColumn("#") { line in
                    Text(String(format: "%03d", line.index))
                        .font(.rsTimecodeSmall)
                        .foregroundColor(.rsTextTertiary)
                }
                .width(30)

                TableColumn(MacStrings.Panel.character) { line in
                    DubCharacterPlate(character: line.character, color: color(for: line))
                }
                .width(min: 54, ideal: 84, max: 120)

                TableColumn(MacStrings.Panel.line) { line in
                    Text(line.caption)
                        .font(.rsMeta)
                        .foregroundColor(.rsTextPrimary)
                        .lineLimit(1)
                        .help(line.caption)
                }
                .width(min: 60, ideal: 160)

                TableColumn(MacStrings.Panel.duration) { line in
                    Text(line.duration.proShortTime)
                        .font(.rsTimecodeSmall)
                        .foregroundColor(.rsTextSecondary)
                }
                .width(min: 58, ideal: 62)

                TableColumn("") { line in
                    status(for: line)
                }
                .width(min: 36, ideal: 44)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .scrollContentBackground(.hidden)
            .background(Color.rsSurface1)
            .contextMenu(forSelectionType: DubLine.ID.self) { ids in
                if let id = ids.first, let line = pack.lines.first(where: { $0.id == id }) {
                    Button(Strings.Dub.recordTake) {
                        viewModel.select(line)
                        viewModel.toggleRecord()
                    }
                    Button(Strings.Dub.playTake) {
                        viewModel.select(line)
                        viewModel.record.playCurrentTake()
                    }
                    .disabled(!session.isRecorded(line))
                    Divider()
                    Button(Strings.Booth.shareLine) {
                        viewModel.beginExport(line: line)
                    }
                    .disabled(!session.isRecorded(line))
                }
            } primaryAction: { ids in
                // Double-click: take the line to the bay and play what's there.
                guard let id = ids.first, let line = pack.lines.first(where: { $0.id == id }) else { return }
                viewModel.setMode(.line)
                viewModel.select(line)
                viewModel.record.toggleReferencePreview()
            }
        }
        .background(Color.rsSurface1)
    }

    private var selection: Binding<DubLine.ID?> {
        Binding(
            get: { session.currentLine?.id },
            set: { viewModel.select(lineID: $0) }
        )
    }

    @ViewBuilder
    private func status(for line: DubLine) -> some View {
        HStack(spacing: 4) {
            if let score = session.score(for: line) {
                DubScoreChip(score: score)
            } else if session.isRecorded(line) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.rsGood)
                    .font(.system(size: 11))
            }

            if session.hasBoothTake(line) {
                Image(systemName: "video.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.rsTextTertiary)
            }
        }
    }

    private func color(for line: DubLine) -> Color {
        DubCharacterStyle.color(for: line.character, in: pack.characters)
    }
}
