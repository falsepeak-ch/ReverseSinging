//
//  GameImitationRoundView.swift
//  DubloonGame
//
//  One sound, played as a quiz-show round: the host behind her podium tells you what to do,
//  counts you in, cheers you on, scores you and tells you what to try next.
//

import SwiftUI
import Combine
import DubAudio
import DubScoring

/// A Sound Imitation round. The game is `ImitationChallengeViewModel`'s, the same as the
/// iPhone app's; this is how it is presented.
///
/// The layout is the quiz podium: the host in the middle of the stage with her speech bubble
/// over her, a desk in front of her holding the sound, a light-up display and the stars, and
/// a deck below that grows from the controls to the full breakdown when the result is in.
struct GameImitationRoundView: View {
    let onNext: (() -> Void)?

    @StateObject private var viewModel: ImitationChallengeViewModel
    @StateObject private var trace: ImitationRoundTrace
    @StateObject private var fxBox = SceneBox(RoundFXScene(reduceMotion: UIAccessibility.isReduceMotionEnabled))
    private var fx: RoundFXScene { fxBox.scene }
    @State private var isHostTalking = false
    /// The display in the desk, in screen points, for the stars to burst from.
    @State private var displayPoint: CGPoint = .zero
    @Environment(\.dismiss) private var dismiss
    @Environment(\.gameCompactDeck) private var compact

    init(sound: ImitationSound, onNext: (() -> Void)?) {
        self.onNext = onNext
        // Inside the autoclosures, so a re-render does not build a recorder and a camera
        // session only to throw them away.
        _viewModel = StateObject(wrappedValue: ImitationChallengeViewModel(sound: sound))
        _trace = StateObject(wrappedValue: ImitationRoundTrace(
            sound: sound,
            axis: ImitationChallengeViewModel.maximumTakeDuration(for: sound)
        ))
    }

    private var sound: ImitationSound { viewModel.sound }
    private var phase: ImitationChallengeViewModel.Phase { viewModel.phase }

    /// The podium: the row with the sound, the display and the stars, over the LED screen.
    private static let deskHeight: CGFloat = 182

    var body: some View {
        GameRoundScaffold(
            mood: mood,
            fx: fx,
            canGoBack: viewModel.exportProgress == nil,
            placeHost: placeHost,
            onBack: { dismiss() }
        ) { size in
            stage(size)
        } deck: {
            deck
        }
        .microphonePrimer()
        .takePaywall(isPresented: $viewModel.isTakePaywallPresented, kind: .imitate)
        .sheet(item: $viewModel.exportedURL) { url in DubShareSheet(url: url) }
        .alert(Strings.Main.Alert.errorTitle, isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button(Strings.Main.Alert.ok, role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert(Strings.Main.Alert.microphoneRequiredTitle, isPresented: $viewModel.showPermissionAlert) {
            Button(Strings.Main.Alert.settings, action: AppSettings.open)
            Button(Strings.Main.Alert.cancel, role: .cancel) {}
        } message: {
            Text(Strings.Main.Alert.microphoneRequiredMessage)
        }
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
        .task { await trace.loadReference() }
        .onChange(of: viewModel.recordingElapsed) { _, elapsed in
            if phase == .recording { trace.record(peak: viewModel.peak, at: elapsed) }
        }
        .onChange(of: phase) { old, new in phaseDidChange(from: old, to: new) }
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: phase)
    }

    // MARK: - Host

    /// The host stands centred behind the desk, her head under the bubble, her waist behind it.
    private func placeHost(_ stage: CGRect) -> HostPlacement {
        let deskTop = stage.maxY - Self.deskHeight - 14
        displayPoint = CGPoint(x: stage.midX, y: deskTop + 60)
        let headTop = stage.minY + min(stage.height * 0.34, 176)
        return HostPlacement(centerX: stage.midX + 6, headTop: headTop, waist: deskTop + 30)
    }

    private var hostLine: String {
        switch phase {
        case .ready: return GameStrings.Round.imitateReady(sound.name)
        case .countingIn: return GameStrings.Round.countIn
        case .recording: return GameStrings.Round.imitateRecording
        case .scoring: return GameStrings.Round.scoring
        case .result: return viewModel.score.map(HostScript.result) ?? GameStrings.Round.scoring
        }
    }

    private var mood: HostMood {
        switch phase {
        case .countingIn, .recording: return .listening
        case .result: return viewModel.verdict?.celebrates == true ? .cheering : .wincing
        case .ready, .scoring: return isHostTalking ? .talking : .idle
        }
    }

    // MARK: - Stage

    private func stage(_ size: CGSize) -> some View {
        VStack(spacing: 10) {
            topBar
            HostBubble(text: hostLine, tail: .bottom, tailPosition: 0.5) { isHostTalking = $0 }
                .frame(maxWidth: min(size.width - 48, 340))
                .padding(.horizontal, 24)
            Spacer(minLength: 0)
            desk
                .padding(.horizontal, 22)
                .padding(.bottom, 14)
        }
    }

    private var topBar: some View {
        HStack {
            Spacer().frame(width: 64)
            Spacer()
            Text(sound.category.title.uppercased())
                .font(.game(13, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(Color.gameCyan)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.gameNavy))
            Spacer()
            StarRow(lit: bestStars, size: 13)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.gameIvory))
                .overlay(Capsule().strokeBorder(Color.gameNavy, lineWidth: 3))
                .padding(.trailing, 16)
                .accessibilityLabel("\(bestStars) / 3")
        }
        .frame(height: 52)
    }

    private var bestStars: Int {
        ImitationProgressStore.shared.best(for: sound).map { ScorePart.stars(for: DubGrade.forScore($0)) } ?? 0
    }

    /// The podium: the sound to copy, the light-up display, and the stars for this take.
    private var desk: some View {
        VStack(spacing: 10) {
        HStack(spacing: 12) {
            Button { viewModel.playReference() } label: {
                GameSoundArt(sound: sound, size: 74)
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: viewModel.playingClip == .reference ? "stop.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(Color.gameNavy)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.gameCyan))
                            .overlay(Circle().strokeBorder(Color.gameNavy, lineWidth: 2.5))
                            .offset(x: 8, y: -8)
                    }
            }
            .buttonStyle(CardPressStyle())
            .disabled(viewModel.isBusy)
            .accessibilityLabel(Strings.Imitate.listen)

            DeskDisplay(
                phase: phase,
                countdown: viewModel.countdown,
                secondsLeft: Int(ceil(max(0, viewModel.maximumTakeDuration - viewModel.recordingElapsed))),
                score: viewModel.score?.overall
            )

            StarColumn(lit: viewModel.score.map { ScorePart.stars(for: $0.grade) } ?? 0, isRevealed: phase == .result) {
                fx.burst(at: displayPoint, count: 16)
            }
        }
            // The desk's LED screen: the target and, once you have gone, your take over it.
            comparison
                .frame(height: 52)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(height: Self.deskHeight)
        .frame(maxWidth: .infinity)
        .background {
            ZStack {
                UnevenRoundedRectangle(topLeadingRadius: 24, bottomLeadingRadius: 12, bottomTrailingRadius: 12, topTrailingRadius: 24, style: .continuous)
                    .fill(Color.gameNavy)
                    .offset(y: 6)
                UnevenRoundedRectangle(topLeadingRadius: 24, bottomLeadingRadius: 12, bottomTrailingRadius: 12, topTrailingRadius: 24, style: .continuous)
                    .fill(LinearGradient(colors: [.gameIvory, Color(gameHex: 0xE8DFC8)], startPoint: .top, endPoint: .bottom))
                UnevenRoundedRectangle(topLeadingRadius: 24, bottomLeadingRadius: 12, bottomTrailingRadius: 12, topTrailingRadius: 24, style: .continuous)
                    .strokeBorder(Color.gameNavy, lineWidth: 4)
            }
        }
        .overlay(alignment: .topTrailing) {
            if phase == .result, let verdict = viewModel.verdict {
                OutlinedText(text: verdict.word.uppercased(), size: 22, color: verdict.celebrates ? .gameGold : .gameCoral)
                    .rotationEffect(.degrees(-6))
                    .offset(x: 6, y: -30)
                    .transition(.scale(scale: 2.2).combined(with: .opacity))
            }
        }
    }

    // MARK: - Deck

    @ViewBuilder
    private var deck: some View {
        if phase == .result, let score = viewModel.score {
            resultDeck(score)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            playDeck
                .transition(.opacity)
        }
    }

    /// Listening and recording: the comparison display and the controls.
    private var playDeck: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                GameRoundButton(
                    symbol: viewModel.playingClip == .reference ? "stop.fill" : "speaker.wave.2.fill",
                    label: Strings.Imitate.listen
                ) { viewModel.playReference() }
                .disabled(viewModel.isBusy)

                Spacer()

                GameMicButton(
                    isRecording: phase == .recording,
                    isCountingIn: phase == .countingIn,
                    progress: min(1, viewModel.recordingElapsed / viewModel.maximumTakeDuration),
                    level: viewModel.level,
                    isEnabled: phase != .scoring && viewModel.exportProgress == nil
                ) {
                    viewModel.toggleRecording()
                }

                Spacer()

                GameRoundButton(symbol: "play.fill", label: Strings.Imitate.playMine) { viewModel.playTake() }
                    .disabled(true)
                    .opacity(0.35)
            }
        }
    }

    /// The result: what the score was made of, the take over the target, and what next.
    private func resultDeck(_ score: ImitationScore) -> some View {
        let parts = HostScript.parts(of: score)
        let weakest = parts.min(by: { $0.value < $1.value })?.id
        return VStack(spacing: compact ? 10 : 14) {
            HStack(spacing: 10) {
                ForEach(parts) { part in
                    ScorePartTile(part: part, isWeakest: part.id == weakest && part.value < 85, order: parts.firstIndex(of: part) ?? 0)
                }
            }

            HStack(spacing: 10) {
                GameRoundButton(
                    symbol: viewModel.playingClip == .take ? "stop.fill" : "play.fill",
                    label: Strings.Imitate.playMine,
                    diameter: 54
                ) { viewModel.playTake() }
                .disabled(viewModel.isBusy)

                Button(Strings.Imitate.tryAgain) { viewModel.toggleRecording() }
                    .buttonStyle(GamePillButtonStyle(fill: .gameCoral, height: 54))
                    .disabled(viewModel.exportProgress != nil)

                if let onNext {
                    Button {
                        viewModel.onDisappear()
                        onNext()
                    } label: {
                        Label(GameStrings.nextSound, systemImage: "forward.fill")
                    }
                    .buttonStyle(GamePillButtonStyle(height: 54))
                    .disabled(viewModel.exportProgress != nil)
                }
            }

            Button {
                viewModel.makeVideo()
            } label: {
                if let progress = viewModel.exportProgress {
                    Text("\(Strings.Imitate.rendering) \(Int(progress * 100))%").monospacedDigit()
                } else {
                    Label(Strings.Imitate.makeVideo, systemImage: "film")
                }
            }
            .font(.game(15, weight: .bold))
            .foregroundStyle(Color.gameCyan)
            .disabled(viewModel.exportProgress != nil)
        }
    }

    private var comparison: some View {
        ComparisonDisplay(
            reference: trace.reference,
            referenceSpan: trace.referenceSpan,
            take: trace.take,
            takeSpan: trace.takeSpan,
            progress: playhead,
            onTap: viewModel.isBusy ? nil : { viewModel.playReference() }
        )
        .accessibilityLabel(Strings.Imitate.listen)
    }

    /// Where the red line is: the clip playing, or the take being recorded.
    private var playhead: Double? {
        switch viewModel.playingClip {
        case .reference: return viewModel.playbackProgress * trace.referenceSpan
        case .take: return viewModel.playbackProgress * trace.takeSpan
        case nil:
            guard phase == .recording else { return nil }
            return min(1, viewModel.recordingElapsed / trace.axis)
        }
    }

    // MARK: - Moments

    private func phaseDidChange(from old: ImitationChallengeViewModel.Phase, to new: ImitationChallengeViewModel.Phase) {
        switch new {
        case .countingIn:
            // Only now, once a take is really starting: a paywall or a refused mic leaves the
            // last take's shape where it was.
            trace.resetTake()
        case .result:
            Task { await trace.loadTake(from: viewModel.takeFileURL) }
            // After the score has rolled up and the stars have landed.
            if let grade = viewModel.score?.grade { fx.finale(for: grade) }
        default:
            break
        }
    }
}

// MARK: - Trace

/// The two shapes on the comparison display, on one time axis: the take's full allowed
/// length, so the target sits at the start and the take runs as long as it ran.
@MainActor
final class ImitationRoundTrace: ObservableObject {
    static let bars = 120

    let sound: ImitationSound
    let axis: TimeInterval

    @Published private(set) var reference: [Float] = []
    @Published private(set) var take: [Float]?
    @Published private(set) var takeSpan: Double = 0
    /// Raw linear peaks, one per bar. Published scaled to the loudest, which is how
    /// `WaveformSampler` hands back the finished take, so the shape holds when the mic closes.
    private var live = [Float](repeating: 0, count: ImitationRoundTrace.bars)
    private var filled = 0
    private var loudest: Float = 0

    init(sound: ImitationSound, axis: TimeInterval) {
        self.sound = sound
        self.axis = max(axis, 0.1)
    }

    var referenceSpan: Double { min(1, sound.duration / axis) }

    func loadReference() async {
        guard let url = sound.url else { return }
        let count = max(8, Int(Double(Self.bars) * referenceSpan))
        reference = await WaveformSampler.shared.samples(from: url, buckets: count)
    }

    func resetTake() {
        live = [Float](repeating: 0, count: Self.bars)
        filled = 0
        loudest = 0
        take = nil
        takeSpan = 0
    }

    /// The live trace: one bar per slice of the axis, filled as the take reaches it.
    func record(peak: Float, at elapsed: TimeInterval) {
        let index = min(Self.bars - 1, Int(elapsed / axis * Double(Self.bars)))
        guard index >= 0 else { return }
        if index >= filled {
            for i in filled...index { live[i] = max(live[i], peak) }
            filled = index + 1
        } else {
            live[index] = max(live[index], peak)
        }
        loudest = max(loudest, peak)
        let scale = loudest > 0 ? 1 / loudest : 0
        take = live.prefix(filled).map { $0 * scale }
        takeSpan = Double(filled) / Double(Self.bars)
    }

    /// The take as recorded, read back off disk once it has been judged.
    func loadTake(from url: URL?) async {
        guard let url,
              let duration = await AudioFileManager.shared.getAudioDurationAsync(from: url), duration > 0 else { return }
        let span = min(1, duration / axis)
        let samples = await WaveformSampler.shared.samples(from: url, buckets: max(8, Int(Double(Self.bars) * span)))
        take = samples
        takeSpan = span
    }
}
