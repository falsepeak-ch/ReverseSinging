//
//  GameDubRoundView.swift
//  DubloonGame
//
//  A scene, dubbed line by line as a game-show round: the scene on the studio monitor, the
//  host coaching from beside it, the line on a cue card, the score on the monitor.
//

import SwiftUI
import DubScoring

struct GameDubRoundView: View {
    @StateObject private var viewModel: GameDubRoundViewModel
    @StateObject private var fxBox = SceneBox(RoundFXScene(reduceMotion: UIAccessibility.isReduceMotionEnabled))
    private var fx: RoundFXScene { fxBox.scene }
    @State private var isHostTalking = false
    @State private var monitorCenter: CGPoint = .zero
    @Environment(\.dismiss) private var dismiss
    @Environment(\.gameCompactDeck) private var compact

    init(pack: DubPack) {
        _viewModel = StateObject(wrappedValue: GameDubRoundViewModel(pack: pack))
    }

    private var session: DubSessionViewModel { viewModel.session }
    private var recorder: DubRecordViewModel { viewModel.recorder }

    /// The strip under the monitor the host and her bubble stand in.
    private static let hostStrip: CGFloat = 150

    var body: some View {
        GameRoundScaffold(
            mood: mood,
            fx: fx,
            placeHost: placeHost,
            onBack: {
                recorder.stop()
                dismiss()
            }
        ) { size in
            stage(size)
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
        .onChange(of: recorder.isRecording) { _, recording in recorder.recordingDidChange(isRecording: recording) }
        .onChange(of: viewModel.reveal) { _, reveal in
            guard let reveal else { return }
            if reveal.grade.celebrates {
                SoundManager.shared.play(.projectorChime)
                fx.confetti()
            } else {
                SoundManager.shared.play(.errorThunk)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: viewModel.reveal)
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: viewModel.isRecording)
        .animation(.easeInOut(duration: 0.2), value: session.currentLineIndex)
    }

    // MARK: - Host

    /// Head and shoulders in the strip under the monitor, at the right, the deck hiding the
    /// rest of her.
    private func placeHost(_ stage: CGRect) -> HostPlacement {
        let strip = min(Self.hostStrip, stage.height * 0.4)
        monitorCenter = CGPoint(x: stage.midX, y: stage.minY + (stage.height - strip) / 2 + 20)
        return HostPlacement(centerX: stage.maxX - 74, headTop: stage.maxY - strip + 4, waist: stage.maxY + strip * 0.55)
    }

    private var mood: HostMood {
        let base = viewModel.mood
        return base == .idle && isHostTalking ? .talking : base
    }

    // MARK: - Stage

    private func stage(_ size: CGSize) -> some View {
        let strip = min(Self.hostStrip, size.height * 0.4)
        return VStack(spacing: 8) {
            topBar
            monitor
                .padding(.horizontal, 12)
                .frame(maxHeight: .infinity)
            HostBubble(text: viewModel.hostLine, tail: .trailing, tailPosition: 0.4) { isHostTalking = $0 }
                .frame(maxWidth: size.width - 150, alignment: .leading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.leading, 16)
                .frame(height: strip)
        }
    }

    private var topBar: some View {
        VStack(spacing: 6) {
            OutlinedText(text: viewModel.pack.title, size: 20, color: .white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            HStack(spacing: 4) {
                ForEach(Array(viewModel.pack.lines.enumerated()), id: \.offset) { index, line in
                    Capsule()
                        .fill(segmentColor(index: index, line: line))
                        .overlay(Capsule().strokeBorder(Color.gameNavy, lineWidth: 2))
                        .frame(height: 9)
                        .frame(maxWidth: 30)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(GameStrings.Dub.lineOf(viewModel.lineNumber, viewModel.pack.lines.count))
        }
        .padding(.horizontal, 74)
        .padding(.top, 2)
        .frame(minHeight: 56)
    }

    private func segmentColor(index: Int, line: DubLine) -> Color {
        if index == session.currentLineIndex { return .white }
        return session.isRecorded(line) ? .gameGold : .white.opacity(0.3)
    }

    /// The scene on a studio monitor. The count, the clock and the score land on it.
    private var monitor: some View {
        ZStack {
            if let line = viewModel.line {
                DubPicture(player: recorder.scenePicture.player, stillURL: viewModel.pack.imageURL(for: line))
                    .id(recorder.scenePicture.player == nil ? line.slug : "video")
                Image("game-scanline")
                    .resizable(resizingMode: .tile)
                    .opacity(0.18)
                    .blendMode(.screen)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }

            if viewModel.isCountingIn {
                Color.black.opacity(0.35)
                Text(recorder.countdown.map(String.init) ?? "")
                    .font(.game(96, weight: .heavy))
                    .foregroundStyle(recorder.countdown == 1 ? Color.gameRed : .white)
                    .shadow(color: .gameNavy, radius: 0, x: 0, y: 5)
                    .contentTransition(.numericText(countsDown: true))
            }

            if let reveal = viewModel.reveal, let verdict = viewModel.verdict {
                Color.gameNavy.opacity(0.6)
                ScoreReveal(score: reveal.overall, grade: reveal.grade, verdict: verdict.word) { _ in
                    fx.burst(at: monitorCenter, count: 16)
                }
                .scaleEffect(0.78)
                .transition(.scale(scale: 0.5).combined(with: .opacity))
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(alignment: .topLeading) {
            if let line = viewModel.line {
                Text(line.character.uppercased())
                    .font(.game(12, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(viewModel.characterColor(for: line)))
                    .overlay(Capsule().strokeBorder(Color.gameNavy, lineWidth: 2.5))
                    .padding(10)
            }
        }
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
                .padding(10)
            } else {
                Text(GameStrings.Dub.lineOf(viewModel.lineNumber, viewModel.pack.lines.count).uppercased())
                    .font(.game(11, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.black.opacity(0.55)))
                    .padding(10)
            }
        }
        .padding(6)
        .gameCard(fill: .gameNavy, radius: 20, lip: 6)
    }

    // MARK: - Deck

    private var deck: some View {
        VStack(spacing: compact ? 10 : 12) {
            if let line = viewModel.line {
                Text("“\(line.caption)”")
                    .font(.game(compact ? 17 : 19, weight: .bold))
                    .foregroundStyle(Color.gameNavy)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .gameCard(radius: 18, lip: 4)
                    .id(line.slug)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            }

            if let reveal = viewModel.reveal {
                let parts = HostScript.parts(of: reveal)
                let weakest = parts.min(by: { $0.value < $1.value })?.id
                HStack(spacing: 10) {
                    ForEach(parts) { part in
                        ScorePartTile(part: part, isWeakest: part.id == weakest && part.value < 85)
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            ComparisonDisplay(
                reference: recorder.referenceSamples,
                take: recorder.takeOverlay,
                progress: viewModel.line.flatMap { recorder.waveformProgress(for: $0) },
                onTap: viewModel.isRecording ? nil : { viewModel.listen() }
            )
            .frame(height: viewModel.isRecording ? (compact ? 72 : 96) : (compact ? 52 : 66))
            .accessibilityLabel(Strings.Dub.listen)

            // One row: step back, listen, record, hear yourself, step on.
            HStack(alignment: .center, spacing: 0) {
                GameRoundButton(symbol: "backward.fill", label: Strings.Dub.previous, diameter: 44) { viewModel.previousLine() }
                    .disabled(!recorder.canGoToPreviousLine)
                    .opacity(recorder.canGoToPreviousLine ? 1 : 0.35)

                Spacer(minLength: 6)

                GameRoundButton(
                    symbol: session.isPreviewingReference ? "stop.fill" : "speaker.wave.2.fill",
                    label: Strings.Dub.listen,
                    diameter: 52
                ) { viewModel.listen() }
                .disabled(viewModel.isRecording)

                Spacer(minLength: 6)

                GameMicButton(
                    isRecording: viewModel.isRecording,
                    isCountingIn: viewModel.isCountingIn,
                    progress: viewModel.line.map { recorder.pacingFraction(for: $0) } ?? 0,
                    level: recorder.recordingLevel,
                    isEnabled: viewModel.line != nil
                ) {
                    viewModel.toggleRecording()
                }
                // The compact key, so five controls share one row.
                .environment(\.gameCompactDeck, true)

                Spacer(minLength: 6)

                GameRoundButton(symbol: "play.fill", label: Strings.Dub.playTake, diameter: 52) { viewModel.playTake() }
                    .disabled(!viewModel.canPlayTake)
                    .opacity(viewModel.canPlayTake ? 1 : 0.35)

                Spacer(minLength: 6)

                GameRoundButton(symbol: "forward.fill", label: Strings.Dub.next, diameter: 44) { viewModel.nextLine() }
                    .disabled(viewModel.isOnLastLine || viewModel.isRecording)
                    .opacity(viewModel.isOnLastLine ? 0.35 : 1)
            }

            // The end of the scene: the way to watch it, only once there is something to watch.
            if viewModel.isOnLastLine, viewModel.hasAnyTake, !viewModel.isRecording {
                Button { viewModel.watchDub() } label: {
                    Label(Strings.Dub.playMyDub, systemImage: "play.rectangle.fill")
                }
                .buttonStyle(GamePillButtonStyle(fill: .gameCoral, height: 52))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}
