//
//  GameImitationRoundView.swift
//  DubloonGame
//
//  One sound, played as a game-show round: hear it, count in, imitate it, get scored.
//

import SwiftUI
import Combine
import DubAudio
import DubScoring

/// A Sound Imitation round. The game is `ImitationChallengeViewModel`'s, the same as the
/// iPhone app's; this is only how it is presented.
struct GameImitationRoundView: View {
    let onNext: (() -> Void)?

    @StateObject private var viewModel: ImitationChallengeViewModel
    @StateObject private var trace: ImitationRoundTrace
    @StateObject private var fxBox = SceneBox(RoundFXScene(reduceMotion: UIAccessibility.isReduceMotionEnabled))
    private var fx: RoundFXScene { fxBox.scene }
    @State private var hasGreeted = false
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

    var body: some View {
        GameRoundScaffold(mood: mood, fx: fx, canGoBack: viewModel.exportProgress == nil, onBack: { dismiss() }) {
            stage
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
            if viewModel.phase == .recording { trace.record(peak: viewModel.peak, at: elapsed) }
        }
        .onChange(of: viewModel.phase) { old, phase in phaseDidChange(from: old, to: phase) }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: viewModel.phase)
    }

    // MARK: - Stage

    private var stage: some View {
        VStack(spacing: 0) {
            OutlinedText(text: caption, size: 26, color: .white)
                .padding(.leading, 70)
                .padding(.trailing, 16)
                .padding(.top, 2)
                .frame(maxWidth: .infinity, minHeight: 92, alignment: .center)
                .id(caption)
                .transition(.scale(scale: 0.8).combined(with: .opacity))

            Spacer(minLength: 0)

            HStack {
                if viewModel.phase == .result, let score = viewModel.score, let verdict = viewModel.verdict {
                    ScoreReveal(score: score.overall, grade: score.grade, verdict: verdict.word) { _ in
                        fx.burst(at: CGPoint(x: 150, y: 260), count: 18)
                    }
                    .frame(width: 230)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
                } else {
                    CountdownCard(
                        countdown: viewModel.countdown,
                        isRecording: viewModel.phase == .recording,
                        secondsLeft: Int(ceil(max(0, viewModel.maximumTakeDuration - viewModel.recordingElapsed)))
                    ) {
                        ImitationSoundArtwork(sound: sound, size: 112)
                    }
                    .padding(.leading, 40)
                }
                Spacer()
            }
            .padding(.bottom, 24)

            Spacer(minLength: 0)
        }
    }

    private var caption: String {
        switch viewModel.phase {
        case .ready: return hasGreeted ? sound.name : GameStrings.Imitate.prompt
        case .countingIn: return GameStrings.getReady
        case .recording: return Strings.Imitate.recordingHint
        case .scoring: return Strings.Imitate.scoring
        case .result: return sound.name
        }
    }

    private var mood: HostMood {
        switch viewModel.phase {
        case .ready: return hasGreeted ? .idle : .talking
        case .countingIn, .recording: return .listening
        case .scoring: return .idle
        case .result: return viewModel.verdict?.celebrates == true ? .cheering : .wincing
        }
    }

    // MARK: - Deck

    private var deck: some View {
        VStack(spacing: compact ? 12 : 18) {
            ComparisonDisplay(
                reference: trace.reference,
                referenceSpan: trace.referenceSpan,
                take: trace.take,
                takeSpan: trace.takeSpan,
                progress: playhead,
                onTap: viewModel.isBusy ? nil : { viewModel.playReference() }
            )
            .frame(height: compact ? 92 : 128)
            .accessibilityLabel(Strings.Imitate.listen)

            HStack(alignment: .center) {
                GameRoundButton(
                    symbol: viewModel.playingClip == .reference ? "stop.fill" : "speaker.wave.2.fill",
                    label: Strings.Imitate.listen
                ) { viewModel.playReference() }
                .disabled(viewModel.isBusy)

                Spacer()

                GameMicButton(
                    isRecording: viewModel.phase == .recording,
                    isCountingIn: viewModel.phase == .countingIn,
                    progress: min(1, viewModel.recordingElapsed / viewModel.maximumTakeDuration),
                    level: viewModel.level,
                    isEnabled: viewModel.phase != .scoring && viewModel.exportProgress == nil
                ) {
                    viewModel.toggleRecording()
                }

                Spacer()

                GameRoundButton(
                    symbol: viewModel.playingClip == .take ? "stop.fill" : "play.fill",
                    label: Strings.Imitate.playMine
                ) { viewModel.playTake() }
                .disabled(viewModel.phase != .result || viewModel.isBusy)
                .opacity(viewModel.phase == .result ? 1 : 0.35)
            }

            if viewModel.phase == .result {
                HStack(spacing: 12) {
                    Button { viewModel.makeVideo() } label: {
                        if let progress = viewModel.exportProgress {
                            Text("\(Int(progress * 100))%").monospacedDigit()
                        } else {
                            Label(Strings.Imitate.makeVideo, systemImage: "film")
                        }
                    }
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
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    /// Where the red line is: the clip playing, or the take being recorded.
    private var playhead: Double? {
        switch viewModel.playingClip {
        case .reference: return viewModel.playbackProgress * trace.referenceSpan
        case .take: return viewModel.playbackProgress * trace.takeSpan
        case nil:
            guard viewModel.phase == .recording else { return nil }
            return min(1, viewModel.recordingElapsed / trace.axis)
        }
    }

    // MARK: - Moments

    private func phaseDidChange(from old: ImitationChallengeViewModel.Phase, to phase: ImitationChallengeViewModel.Phase) {
        if old == .ready, !hasGreeted { hasGreeted = true }
        switch phase {
        case .countingIn:
            // Only now, once a take is really starting: a paywall or a refused mic leaves the
            // last take's shape where it was.
            trace.resetTake()
        case .result:
            Task { await trace.loadTake(from: viewModel.takeFileURL) }
            if viewModel.verdict?.celebrates == true {
                SoundManager.shared.play(.projectorChime)
                fx.confetti()
            } else {
                SoundManager.shared.play(.errorThunk)
            }
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
