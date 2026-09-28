//
//  ReverseInspector.swift
//  DubloonMac
//
//  The score, the playback knobs, and the session
//

import SwiftUI

struct ReverseInspector: View {
    @ObservedObject var viewModel: ReverseStudioViewModel
    @ObservedObject var workspace: MacWorkspaceViewModel

    private var game: ReverseGameViewModel { viewModel.game }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let score = viewModel.score {
                    scoreSection(score)
                }

                audioSection

                sessionSection
            }
        }
        .background(Color.rsSurface1)
    }

    // MARK: - Score

    private func scoreSection(_ score: Double) -> some View {
        ProInspectorSection(title: Strings.ScoreCard.title) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(ScoreCard.letterGrade(for: score))
                    .font(.system(size: 44, weight: .heavy))
                    .foregroundColor(gradeColor(score))
                VStack(alignment: .leading, spacing: 2) {
                    Text(ScoreCard.gradeDescription(for: score))
                        .font(.rsMeta)
                        .foregroundColor(.rsTextPrimary)
                    Text("\(Int(score.rounded()))%")
                        .font(.rsTimecodeSmall)
                        .foregroundColor(.rsTextSecondary)
                }
            }

            DubScoreBar(label: Strings.ScoreCard.title, value: score, tint: gradeColor(score))

            ProInspectorRow(label: MacStrings.Panel.attempts, value: "\(game.appState.attemptCount)")
        }
    }

    private func gradeColor(_ score: Double) -> Color {
        switch score {
        case 85...: .rsGood
        case 55..<85: .rsCaution
        default: .rsRecord
        }
    }

    // MARK: - Audio

    private var audioSection: some View {
        ProInspectorSection(title: Strings.TimerCard.audioControls) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(Strings.TimerCard.speed).font(.rsMeta).foregroundColor(.rsTextSecondary)
                    Spacer()
                    Text(String(format: "%.2f×", game.appState.playbackSpeed))
                        .font(.rsTimecodeSmall)
                        .foregroundColor(.rsTextPrimary)
                }
                Slider(
                    value: Binding(get: { game.appState.playbackSpeed }, set: { game.setPlaybackSpeed($0) }),
                    in: 0.5...2.0,
                    step: 0.05
                )
                .controlSize(.small)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(Strings.TimerCard.pitch).font(.rsMeta).foregroundColor(.rsTextSecondary)
                    Spacer()
                    Text(String(format: "%+d %@", Int((game.appState.pitchShift / 100).rounded()), Strings.TimerCard.semitones))
                        .font(.rsTimecodeSmall)
                        .foregroundColor(.rsTextPrimary)
                }
                Slider(
                    value: Binding(
                        get: { Double(game.appState.pitchShift) },
                        set: { game.setPitchShift(Float($0)) }
                    ),
                    in: -1200...1200,
                    step: 100
                )
                .controlSize(.small)
            }

            Toggle(isOn: Binding(get: { game.appState.isLooping }, set: { _ in game.toggleLooping() })) {
                Text(Strings.TimerCard.loop).font(.rsMeta)
            }
            .platformSwitch()
        }
    }

    // MARK: - Session

    private var sessionSection: some View {
        ProInspectorSection(title: Strings.Main.Section.session) {
            if let session = viewModel.session {
                ProInspectorRow(label: Strings.Session.defaultName, value: session.name)
                ProInspectorRow(label: MacStrings.Panel.start, value: session.formattedDate)
            }

            if let archived = viewModel.archived {
                Button(role: .destructive) {
                    workspace.deleteSession(archived)
                } label: {
                    Label(Strings.Dub.delete, systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
            } else {
                Button {
                    viewModel.newSession()
                } label: {
                    Label(Strings.Main.newSession, systemImage: "plus.square.on.square")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .disabled(!viewModel.hasRecordings || viewModel.isRecording)
            }
        }
    }
}
