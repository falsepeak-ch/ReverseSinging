//
//  GameDubRoundView.swift
//  DubloonGame
//
//  A scene, dubbed line by line as a game-show round: the scene on the studio monitor, the
//  line on a cue card, your take over the original on the display, the score on the monitor.
//

import SwiftUI
import DubScoring

struct GameDubRoundView: View {
    @StateObject private var viewModel: GameDubRoundViewModel
    @ObservedObject private var scoring = DubScoringPreference.shared
    @StateObject private var fxBox = SceneBox(RoundFXScene(reduceMotion: UIAccessibility.isReduceMotionEnabled))
    private var fx: RoundFXScene { fxBox.scene }
    @Environment(\.dismiss) private var dismiss
    @Environment(\.gameCompactDeck) private var compact

    init(pack: DubPack) {
        _viewModel = StateObject(wrappedValue: GameDubRoundViewModel(pack: pack))
    }

    private var session: DubSessionViewModel { viewModel.session }
    private var recorder: DubRecordViewModel { viewModel.recorder }

    var body: some View {
        GameRoundScaffold(mood: viewModel.mood, fx: fx, stageShare: 0.47, onBack: {
            recorder.stop()
            dismiss()
        }) {
            stage
        } deck: {
            deck
        }
        .microphonePrimer()
        .takePaywall(isPresented: Binding(
            get: { recorder.isTakePaywallPresented },
            set: { recorder.isTakePaywallPresented = $0 }
        ), kind: .dub)
        .alert(Strings.Main.Alert.microphoneRequiredTitle, isPresented: Binding(
            get: { recorder.showPermissionAlert },
            set: { recorder.showPermissionAlert = $0 }
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
        .coversScreen(item: $viewModel.playbackMode) { mode in
            DubPlaybackView(session: session, mode: mode)
                .cinemaAppearance()
        }
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
        // The recorder's own hooks, as the iPhone app's record screen wires them.
        .onChange(of: session.currentLineIndex) { _, _ in recorder.lineDidChange() }
        .onChange(of: session.isPreviewingReference) { _, previewing in recorder.previewDidChange(isPreviewing: previewing) }
        .onChange(of: recorder.recordingAnchor) { _, anchor in recorder.recordingAnchorDidChange(anchor) }
        .onChange(of: recorder.isRecording) { _, recording in
            recorder.recordingDidChange(isRecording: recording)
        }
        .onChange(of: viewModel.reveal) { _, reveal in
            guard let reveal else { return }
            if reveal.grade.celebrates {
                SoundManager.shared.play(.projectorChime)
                fx.confetti()
            } else {
                SoundManager.shared.play(.errorThunk)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: viewModel.reveal)
        .animation(.easeInOut(duration: 0.2), value: session.currentLineIndex)
    }

    // MARK: - Stage

    private var stage: some View {
        VStack(spacing: 10) {
            OutlinedText(text: viewModel.pack.title, size: 22, color: .white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.leading, 70)
                .padding(.trailing, 16)
                .frame(maxWidth: .infinity, minHeight: 54)

            monitor
                .padding(.horizontal, 16)
                .padding(.trailing, 64)

            Spacer(minLength: 0)
        }
    }

    /// The scene, on a studio monitor in the kit's style. The count and the score land on it.
    private var monitor: some View {
        ZStack {
            if let line = viewModel.line {
                DubPicture(player: recorder.scenePicture.player, stillURL: viewModel.pack.imageURL(for: line))
                    .id(recorder.scenePicture.player == nil ? line.slug : "video")
            }

            if viewModel.isCountingIn || viewModel.isRecording {
                Color.black.opacity(viewModel.isCountingIn ? 0.35 : 0)
                CountdownCard(countdown: recorder.countdown, isRecording: false, secondsLeft: nil) { EmptyView() }
                    .scaleEffect(0.62)
                    .opacity(viewModel.isCountingIn ? 1 : 0)
            }

            if let reveal = viewModel.reveal, let verdict = viewModel.verdict {
                Color.gameNavy.opacity(0.55)
                ScoreReveal(score: reveal.overall, grade: reveal.grade, verdict: verdict.word) { _ in
                    fx.burst(at: CGPoint(x: 180, y: 220), count: 16)
                }
                .scaleEffect(0.8)
                .transition(.scale(scale: 0.5).combined(with: .opacity))
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(6)
        .gameCard(fill: .gameNavy, radius: 20, lip: 6)
        .overlay(alignment: .topTrailing) {
            if viewModel.isRecording {
                HStack(spacing: 6) {
                    Circle().fill(Color.gameRed).frame(width: 10, height: 10)
                    Text(viewModel.secondsLeft.map { "\($0)" } ?? "")
                        .font(.game(16))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.black.opacity(0.6)))
                .padding(14)
            }
        }
    }

    // MARK: - Deck

    private var deck: some View {
        VStack(spacing: compact ? 10 : 14) {
            if let line = viewModel.line {
                cueCard(for: line)
            }

            ComparisonDisplay(
                reference: recorder.referenceSamples,
                take: recorder.takeOverlay,
                progress: viewModel.line.flatMap { recorder.waveformProgress(for: $0) },
                onTap: viewModel.isRecording ? nil : { viewModel.listen() }
            )
            .frame(height: compact ? 60 : 84)
            .accessibilityLabel(Strings.Dub.listen)

            HStack(alignment: .center) {
                GameRoundButton(
                    symbol: session.isPreviewingReference ? "stop.fill" : "speaker.wave.2.fill",
                    label: Strings.Dub.listen
                ) { viewModel.listen() }
                .disabled(viewModel.isRecording)

                Spacer()

                GameMicButton(
                    isRecording: viewModel.isRecording,
                    isCountingIn: viewModel.isCountingIn,
                    progress: viewModel.line.map { recorder.pacingFraction(for: $0) } ?? 0,
                    level: recorder.recordingLevel,
                    isEnabled: viewModel.line != nil
                ) {
                    viewModel.toggleRecording()
                }

                Spacer()

                GameRoundButton(symbol: "play.fill", label: Strings.Dub.playTake) { viewModel.playTake() }
                    .disabled(!(viewModel.line.map { recorder.canPlayTake(of: $0) } ?? false))
                    .opacity(viewModel.line.map { recorder.canPlayTake(of: $0) } ?? false ? 1 : 0.35)
            }

            footer
        }
    }

    /// The line to say, on an ivory cue card with the speaker's name on a coloured tab.
    private func cueCard(for line: DubLine) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(line.character.uppercased())
                    .font(.game(13))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(viewModel.characterColor(for: line)))
                    .overlay(Capsule().strokeBorder(Color.gameNavy, lineWidth: 2))
                Spacer()
                Text(GameStrings.Dub.lineOf(viewModel.lineNumber, viewModel.pack.lines.count))
                    .font(.game(13, weight: .bold))
                    .foregroundStyle(Color.gameNavy.opacity(0.7))
            }

            Text(line.caption)
                .font(.game(19, weight: .bold))
                .foregroundStyle(Color.gameNavy)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .gameCard(radius: 18, lip: 4)
        .id(line.slug)
        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
    }

    /// Back and forth between lines, and the way out to watch the dub once there is one.
    private var footer: some View {
        HStack(spacing: 12) {
            Button { viewModel.previousLine() } label: {
                Image(systemName: "backward.fill")
            }
            .buttonStyle(GamePillButtonStyle(fill: .gameIvory, height: 50, text: .gameNavy))
            .disabled(!recorder.canGoToPreviousLine)
            .opacity(recorder.canGoToPreviousLine ? 1 : 0.4)
            .accessibilityLabel(Strings.Dub.previous)

            if viewModel.isOnLastLine {
                Button { viewModel.watchDub() } label: {
                    Label(Strings.Dub.playMyDub, systemImage: "play.rectangle.fill")
                }
                .buttonStyle(GamePillButtonStyle(fill: .gameCoral, height: 50))
                .disabled(!viewModel.hasAnyTake || viewModel.isRecording)
            } else {
                Button { viewModel.nextLine() } label: {
                    Label(Strings.Dub.next, systemImage: "forward.fill")
                }
                .buttonStyle(GamePillButtonStyle(height: 50))
                .disabled(viewModel.isRecording)
            }
        }
    }
}
