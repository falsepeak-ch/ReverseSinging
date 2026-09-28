//
//  ImitateSoundBrowser.swift
//  DubloonMac
//
//  The sound library as a browser: a category filter over a dense table of sounds
//

import SwiftUI
import DubScoring

/// Every sound as a row, the way a loop or sample browser lists its library: a small icon and
/// the name, how hard it is, how long it runs and the best grade so far. The filter above
/// narrows it to one category; ↑ and ↓ walk it, and a double-click goes straight to recording.
struct ImitateSoundBrowser: View {
    @ObservedObject var viewModel: ImitateStudioViewModel

    var body: some View {
        VStack(spacing: 0) {
            ProPanelHeader(
                title: GameMode.imitate.title,
                subtitle: String(format: "%02d", viewModel.visibleSounds.count)
            )

            filter
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.rsSurface1)
                .overlay(alignment: .bottom) { EditorRule() }

            Table(viewModel.visibleSounds, selection: selection) {
                TableColumn(MacStrings.Panel.sound) { sound in
                    HStack(spacing: 8) {
                        ImitationSoundArtwork(sound: sound, size: 20)
                        Text(sound.name)
                            .font(.rsMeta)
                            .foregroundColor(.rsTextPrimary)
                            .lineLimit(1)
                    }
                }
                .width(min: 110, ideal: 150)

                TableColumn(Strings.Imitate.difficulty) { sound in
                    DifficultyMeter(level: sound.difficulty)
                        .help(Strings.Imitate.difficulty)
                }
                .width(min: 58, ideal: 62)

                TableColumn(MacStrings.Panel.duration) { sound in
                    Text(sound.duration.proShortTime)
                        .font(.rsTimecodeSmall)
                        .foregroundColor(.rsTextSecondary)
                }
                .width(min: 50, ideal: 54)

                TableColumn(Strings.Imitate.best) { sound in
                    GradeChip(grade: viewModel.library.grade(for: sound), best: viewModel.library.best(for: sound))
                }
                .width(min: 36, ideal: 42)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .scrollContentBackground(.hidden)
            .background(Color.rsSurface1)
            .contextMenu(forSelectionType: ImitationSound.ID.self) { ids in
                if let id = ids.first {
                    Button(MacStrings.Menu.listen) {
                        viewModel.select(id: id)
                        viewModel.challenge?.playReference()
                    }
                    Button(MacStrings.Menu.record) {
                        viewModel.select(id: id)
                        viewModel.challenge?.toggleRecording()
                    }
                }
            } primaryAction: { ids in
                // Double-click: this one, now.
                guard let id = ids.first else { return }
                viewModel.select(id: id)
                viewModel.challenge?.toggleRecording()
            }
        }
        .background(Color.rsSurface1)
    }

    private var selection: Binding<ImitationSound.ID?> {
        Binding(
            get: { viewModel.selectedSound?.id },
            set: { viewModel.select(id: $0) }
        )
    }

    /// Segments while the category names fit across, a pop-up button when they do not.
    private var filter: some View {
        ViewThatFits(in: .horizontal) {
            filterPicker.pickerStyle(.segmented)
            filterPicker.pickerStyle(.menu)
        }
        .labelsHidden()
        .controlSize(.small)
    }

    private var filterPicker: some View {
        Picker(MacStrings.Panel.allSounds, selection: $viewModel.category) {
            Text(MacStrings.Panel.allSounds).tag(ImitationCategory?.none)
            ForEach(viewModel.library.categories) { category in
                Text(category.title).tag(ImitationCategory?.some(category))
            }
        }
    }
}

// MARK: - Cells

/// How hard a sound is, as three rising bars, lit up to its level.
struct DifficultyMeter: View {
    let level: Int

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(1...3, id: \.self) { step in
                RoundedRectangle(cornerRadius: 1)
                    .fill(step <= level ? tint : Color.rsSurface3)
                    .frame(width: 4, height: CGFloat(4 + step * 3))
            }
        }
        .frame(height: 13, alignment: .bottom)
        .accessibilityLabel("\(Strings.Imitate.difficulty) \(level)/3")
    }

    private var tint: Color {
        switch level {
        case 1: .rsGood
        case 2: .rsHighlight
        default: .rsRecord
        }
    }
}

/// The best grade so far, boxed like a take's grade in the dub browser; a dash when untried.
private struct GradeChip: View {
    let grade: DubGrade?
    let best: Double?

    var body: some View {
        if let grade, let best {
            Text(grade.badge)
                .font(.rsTimecodeSmall)
                .foregroundColor(grade.color)
                .frame(minWidth: 24)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 3, style: .continuous).fill(grade.color.opacity(0.14)))
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(grade.color.opacity(0.4), lineWidth: EditorMetrics.hairline)
                )
                .help("\(Strings.Imitate.best): \(Int(best.rounded()))")
        } else {
            Text(verbatim: "—")
                .font(.rsTimecodeSmall)
                .foregroundColor(.rsTextTertiary)
        }
    }
}
