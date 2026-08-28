//
//  DubPackDetailView.swift
//  ReverseSinging
//
//  One pack: what it is, what you've dubbed, and what you can do with it
//

import SwiftUI

struct DubPackDetailView: View {
    let pack: DubPack
    @ObservedObject var library: DubPackLibrary

    @StateObject private var viewModel: DubViewModel
    @ObservedObject private var scoring = DubScoringPreference.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var showRecorder = false
    @State private var showShareNotice = false
    @State private var playbackMode: DubPlaybackMode?
    @State private var reelIsBreathing = false
    /// True for a pack whose video was converted by a build that dropped duplicate frames.
    ///
    /// Reads the file, so it is settled once when the screen appears rather than on every
    /// evaluation of the body.
    @State private var videoNeedsReimport = false

    init(pack: DubPack, library: DubPackLibrary) {
        self.pack = pack
        self.library = library
        _viewModel = StateObject(wrappedValue: DubViewModel(pack: pack))
    }

    var body: some View {
        ZStack {
            Color.rsSurface0
                .ignoresSafeArea()
                .filmGrain()

            // The same header the library and the games use, so a push never
            // swaps one kind of chrome for another.
            VStack(spacing: 0) {
                EditorScreenHeader(title: pack.title, onBack: { dismiss() })

                ScrollView {
                    VStack(spacing: 24) {
                        hero

                        if videoNeedsReimport {
                            reimportNotice
                        }

                        if scoring.isEnabled {
                            sceneScore
                        }

                        actions
                        lineList

                        if pack.hasAttribution {
                            attribution
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .ignoresSafeArea(edges: .top)

            if viewModel.isExporting {
                exportOverlay
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: $showRecorder) {
            DubRecordView(viewModel: viewModel)
        }
        .fullScreenCover(item: $playbackMode) { mode in
            DubPlaybackView(viewModel: viewModel, mode: mode)
        }
        .dubShareNotice(isPresented: $showShareNotice, pack: pack) {
            Task { await viewModel.export() }
        }
        .sheet(item: $viewModel.exportedURL) { url in
            DubShareSheet(url: url)
        }
        .alert(Strings.Main.Alert.errorTitle, isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button(Strings.Main.Alert.ok, role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .task {
            let pack = pack
            videoNeedsReimport = await Task.detached(priority: .utility) {
                DubPackLibrary.sceneVideoIsTruncated(pack)
            }.value
        }
        .onAppear {
            AnalyticsManager.shared.trackScreenViewed(screenName: "DubPackDetail")
            #if DEBUG
            applyScreenshotPose()
            #endif
        }
        #if DEBUG
        .task {
            guard ScreenshotMode.isActive, ScreenshotMode.destination?.isTour == true else { return }
            await runScreenshotTour()
        }
        #endif
        // Keyed on the preference, so switching scoring on from the library and coming
        // straight back marks what is already here rather than showing a half-empty panel.
        .task(id: scoring.isEnabled) {
            guard scoring.isEnabled else { return }
            await viewModel.scoreTakesRecordedBeforeScoringWasOn()
            AnalyticsManager.shared.trackDubSceneScored(
                score: viewModel.sceneScore.overall,
                recordedLines: viewModel.sceneScore.recordedLines,
                totalLines: pack.lines.count
            )
        }
        .onDisappear {
            viewModel.stopEverything()
            library.reload()
        }
        .animation(.rsSpring, value: viewModel.isExporting)
    }

    // MARK: - Damaged Video

    /// Tells the user why the picture is ahead of the voices, and what to do about it.
    ///
    /// The pack's Theora original is deleted once converted, so there is nothing left on the
    /// device to convert again, importing the pack afresh is genuinely the only fix, and
    /// saying so beats letting the scene play out of sync with no explanation.
    private var reimportNotice: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.rsHighlight)

            Text(Strings.Dub.videoNeedsReimport)
                .font(.rsCaption)
                .foregroundColor(.rsTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.rsSurface2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(Color.rsHighlight.opacity(0.4), lineWidth: EditorMetrics.hairline)
        )
        .padding(.horizontal, EditorMetrics.gutter)
    }

    // MARK: - Screenshots

    #if DEBUG
    /// Keeps the reference playing under the record screen, so the still lands on a
    /// moving picture.
    ///
    /// The scenes ship with video, and the bay only rolls it while the line is being heard
    /// or performed. Sitting idle it shows the line's still, and a screenshot of that is a
    /// screenshot of a photograph in a dark frame; a screenshot mid-playback is the app
    /// doing the thing it is for. The line is barely two seconds long, so this restarts it
    /// rather than firing once and hoping the shutter agrees.
    private func keepScenePictureRolling() {
        Task {
            for _ in 0..<160 {
                if !viewModel.isPreviewingReference {
                    viewModel.toggleReferencePreview()
                }
                try? await Task.sleep(for: .milliseconds(250))
                if Task.isCancelled { return }
            }
        }
    }

    /// The App Store app preview, played by the app itself.
    ///
    /// Recorded with `simctl io recordVideo` while this runs, once per locale. Driving it
    /// from inside means the same 30 seconds come out of every locale, which tapping a
    /// simulator by hand could never promise. And the whole thing is real app in real
    /// use, which is what Apple requires of a preview.
    private func runScreenshotTour() async {
        let tour = ScreenshotMode.Tour.self

        func hold(_ seconds: TimeInterval) async {
            try? await Task.sleep(for: .seconds(seconds))
        }

        // 1. The pack: what a scene is, who is in it, how far in you are.
        await hold(tour.detailHold)

        // 2. The bay, on a line already dubbed, so the take is drawn over the reference.
        showRecorder = true
        await hold(tour.recorderOpen)

        // 3. Hear the original, then hear yourself against it.
        viewModel.toggleReferencePreview()
        await hold(tour.listen)
        viewModel.playCurrentTake()
        await hold(tour.playTake)

        // 4. The line-by-line loop, which is the actual shape of the game.
        viewModel.goToNextLine()
        await hold(tour.lineStep)
        viewModel.goToNextLine()
        await hold(tour.lineStep)

        // 5. Back out and watch the scene with your own voice in it.
        viewModel.stopEverything()
        showRecorder = false
        await hold(tour.backToDetail)
        playbackMode = .myDub
        await hold(tour.playback)
        playbackMode = nil
        await hold(tour.beforeExport)

        // 6. The render, which is what you came for.
        await viewModel.runExportRampForScreenshot(over: tour.exportRamp)
        await hold(tour.tail)
    }

    /// Puts the session partway in, a line selected, takes behind it, and opens
    /// whichever full-screen surface the capture script asked for.
    private func applyScreenshotPose() {
        guard ScreenshotMode.isActive, let destination = ScreenshotMode.destination else { return }

        if viewModel.pack.lines.indices.contains(ScreenshotMode.posedLineIndex) {
            viewModel.select(viewModel.pack.lines[ScreenshotMode.posedLineIndex])
        }

        if destination.opensRecorder {
            showRecorder = true
            keepScenePictureRolling()
        } else if destination.posesExport {
            viewModel.poseExportForScreenshot(progress: ScreenshotMode.posedExportProgress)
        }
    }
    #endif

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                DubStillImage(url: pack.iconURL)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .cinemaVignette(strength: 0.45)

                LinearGradient(
                    colors: [.clear, .rsSurface0.opacity(0.9)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .frame(height: 200)
                .allowsHitTesting(false)
            }

            // Slate: the facts about this scene, set like a camera report
            HStack(spacing: 0) {
                slateField(
                    Strings.Dub.slateLines,
                    "\(viewModel.recordedCount)/\(pack.lines.count)"
                )
                slateDivider
                slateField(Strings.Dub.slateDuration, pack.formattedDuration)
                slateDivider
                if scoring.isEnabled {
                    slateField(
                        Strings.Dub.Score.slate,
                        viewModel.sceneScore.recordedLines > 0
                            ? String(format: "%d", Int(viewModel.sceneScore.overall.rounded()))
                            : "-",
                        tint: viewModel.sceneScore.recordedLines > 0
                            ? viewModel.sceneScore.grade.color
                            : .rsTextPrimary
                    )
                } else {
                    slateField(
                        Strings.Dub.slateCast,
                        String(format: "%02d", pack.characters.count)
                    )
                }
            }
            .frame(height: 54)
            .background(Color.rsSurface1)
            .overlay(alignment: .top) { EditorRule() }
            .overlay(alignment: .bottom) { EditorRule() }

            castStrip
        }
    }

    /// The cast, in the colours they keep for the rest of the scene. This is where the
    /// association between a person and a colour is learned, before a single line is played.
    private var castStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                Text(Strings.Dub.cast)
                    .editorLabelStyle()

                ForEach(pack.characters, id: \.self) { character in
                    DubCharacterPlate(
                        character: character,
                        color: DubCharacterStyle.color(for: character, in: pack.characters)
                    )
                }
            }
            .padding(.horizontal, EditorMetrics.gutter)
            .padding(.vertical, 10)
        }
        .background(Color.rsSurface0)
        .overlay(alignment: .bottom) { EditorRule() }
    }

    private func slateField(_ label: String, _ value: String, tint: Color = .rsTextPrimary) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .editorLabelStyle()
            Text(value)
                .font(.rsTimecode)
                .foregroundColor(tint)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Scene Score

    private var sceneScore: some View {
        VStack(alignment: .leading, spacing: 10) {
            EditorSectionHeader(title: Strings.Dub.Score.sceneTitle)

            DubSceneScorePanel(
                score: viewModel.sceneScore,
                line: { slug in pack.lines.first { $0.slug == slug } }
            )
        }
        .padding(.horizontal, EditorMetrics.gutter)
    }

    private var slateDivider: some View {
        Rectangle()
            .fill(Color.rsStroke)
            .frame(width: EditorMetrics.hairline, height: 26)
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(alignment: .leading, spacing: 10) {
            EditorSectionHeader(title: Strings.Main.Section.transport)

            VStack(spacing: 8) {
                LargeActionButton(
                    title: viewModel.hasAnyTake ? Strings.Dub.continueRecording : Strings.Dub.record,
                    subtitle: viewModel.currentLine?.character,
                    icon: "mic.fill",
                    dotCount: 0,
                    color: .rsRecord,
                    isEnabled: true,
                    recordingLevel: 0,
                    action: {
                        viewModel.jumpToFirstUnrecordedLine()
                        showRecorder = true
                    }
                )

                LargeActionButton(
                    title: Strings.Dub.playOriginal,
                    subtitle: pack.formattedDuration,
                    icon: "play.fill",
                    dotCount: 0,
                    color: .rsHighlight,
                    isEnabled: true,
                    recordingLevel: 0,
                    action: { playbackMode = .original }
                )

                LargeActionButton(
                    title: Strings.Dub.playMyDub,
                    subtitle: viewModel.hasAnyTake ? nil : Strings.Dub.noTakesYet,
                    icon: "person.wave.2.fill",
                    dotCount: 0,
                    color: .rsGood,
                    isEnabled: viewModel.hasAnyTake,
                    recordingLevel: 0,
                    action: { playbackMode = .myDub }
                )

                // Through the notice, never straight to the export: the file about to be
                // made is the user's voice over someone else's picture, and this is the
                // only moment where saying so is about something concrete.
                BigButton(
                    title: Strings.Dub.export,
                    icon: "square.and.arrow.up",
                    color: .rsTextPrimary,
                    action: { showShareNotice = true },
                    isEnabled: viewModel.hasAnyTake && !viewModel.isExporting,
                    style: .secondary
                )
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, EditorMetrics.gutter)
    }

    // MARK: - Line List

    private var lineList: some View {
        VStack(alignment: .leading, spacing: 10) {
            EditorSectionHeader(
                title: Strings.Dub.lines,
                trailing: String(format: "%02d", pack.lines.count)
            )

            LazyVStack(spacing: 0) {
                ForEach(Array(pack.lines.enumerated()), id: \.element.id) { index, line in
                    Button {
                        viewModel.select(line)
                        showRecorder = true
                    } label: {
                        DubLineRow(
                            line: line,
                            isRecorded: viewModel.isRecorded(line),
                            score: viewModel.score(for: line),
                            characterColor: DubCharacterStyle.color(
                                for: line.character,
                                in: pack.characters
                            )
                        )
                    }
                    .buttonStyle(.plain)

                    if index < pack.lines.count - 1 {
                        EditorRule()
                    }
                }
            }
            .editorPanel()
        }
        .padding(.horizontal, EditorMetrics.gutter)
    }

    // MARK: - Attribution

    /// Who made the scene this pack was cut from, and on what terms.
    ///
    /// The starter packs are cut from someone else's film under CC BY, where credit is
    /// not a courtesy but the condition the licence is granted on. And a credit that
    /// lives only inside the zip discharges nothing. It sits under the line list rather
    /// than in the slate: the slate is a three-field camera report about *this* scene,
    /// and this is a sentence about a film that is not ours.
    ///
    /// Absent entirely for a pack that claims no provenance, which is most packs people
    /// build for themselves.
    private var attribution: some View {
        VStack(alignment: .leading, spacing: 10) {
            EditorSectionHeader(title: Strings.Dub.attribution)

            VStack(alignment: .leading, spacing: 8) {
                if let source = pack.source {
                    Text(source)
                        .font(.rsCaption)
                        .foregroundColor(.rsTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let rights = pack.rightsLabel {
                    attributionLink(
                        icon: "checkmark.seal",
                        text: rights,
                        url: pack.rightsURL
                    )
                }

                if let sourceLink = pack.sourceLink {
                    attributionLink(
                        icon: "link",
                        text: sourceLink.host() ?? sourceLink.absoluteString,
                        url: sourceLink
                    )
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .editorPanel(.rsSurface2)
        }
        .padding(.horizontal, EditorMetrics.gutter)
    }

    /// One provenance line. Tappable only when it actually points somewhere, a public
    /// domain finding has no deed to open, and a link that does nothing is worse than text.
    @ViewBuilder
    private func attributionLink(icon: String, text: String, url: URL?) -> some View {
        let row = HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(url == nil ? .rsTextTertiary : .rsHighlight)
                .frame(width: 14)

            Text(text)
                .font(.rsMeta)
                .foregroundColor(url == nil ? .rsTextSecondary : .rsHighlight)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }

        if let url {
            Button { openURL(url) } label: { row }
                .buttonStyle(.plain)
                .accessibilityAddTraits(.isLink)
        } else {
            row
        }
    }

    // MARK: - Export Overlay

    private var exportOverlay: some View {
        ZStack {
            Color.rsSurface0.opacity(0.86)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                // The reel breathes quietly for as long as the render runs
                Image("film-reel")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .scaleEffect(reelIsBreathing ? 1.04 : 0.96)
                    .opacity(reelIsBreathing ? 1 : 0.82)
                    .frame(maxWidth: .infinity)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                            reelIsBreathing = true
                        }
                    }
                    .onDisappear { reelIsBreathing = false }

                HStack {
                    Text(Strings.Dub.exporting)
                        .editorLabelStyle(.rsTextSecondary)
                    Spacer()
                    Text("\(Int(viewModel.exportProgress * 100))%")
                        .font(.rsTimecode)
                        .foregroundColor(.rsTextPrimary)
                }

                EditorTrack(progress: viewModel.exportProgress, showsPlayhead: false)

                Text(viewModel.exportStage.message)
                    .font(.rsBodySmall)
                    .foregroundColor(.rsTextTertiary)
            }
            .padding(18)
            .frame(width: 280)
            .editorPanel(.rsSurface2)
            .cardShadow(.floating)
        }
        .transition(.opacity)
    }
}

// MARK: - Line Row

struct DubLineRow: View {
    let line: DubLine
    let isRecorded: Bool
    var score: DubLineScore?
    let characterColor: Color

    var body: some View {
        HStack(spacing: 12) {
            Text(String(format: "%03d", line.index))
                .font(.rsTimecodeSmall)
                .foregroundColor(.rsTextTertiary)

            Rectangle()
                .fill(statusColor)
                .frame(width: 2, height: 30)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    DubCharacterPlate(character: line.character, color: characterColor)

                    Text(line.formattedStartTime)
                        .font(.rsTimecodeSmall)
                        .foregroundColor(.rsTextTertiary)
                }

                Text(line.caption)
                    .font(.rsBodySmall)
                    .foregroundColor(isRecorded ? .rsTextPrimary : .rsTextSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 8)

            // The grade stands in for the tick: a scored line is a recorded line, and
            // "how did it go" is more use than "is there a file".
            if let score {
                DubScoreChip(score: score)
            } else {
                Image(systemName: isRecorded ? "checkmark" : "circle.dashed")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isRecorded ? .rsGood : .rsTextTertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// The spine beside the index: graded once there is a score, plain green for a take that
    /// could not be measured, and inert until something has been recorded.
    private var statusColor: Color {
        if let score { return score.grade.color }
        return isRecorded ? .rsGood : .rsSurface3
    }
}

// MARK: - Share Sheet

struct DubShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

// MARK: - Presentation Helpers

extension DubPlaybackMode: Identifiable {
    var id: String { rawValue }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
