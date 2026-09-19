//
//  DubPackDetailView.swift
//  ReverseSinging
//
//  One pack: what it is, what you've dubbed, and what you can do with it
//

import SwiftUI
import TipKit
import DubScoring
import DubCompositing

struct DubPackDetailView: View {
    let pack: DubPack

    @StateObject private var viewModel: DubPackDetailViewModel
    @ObservedObject private var scoring = DubScoringPreference.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var reelIsBreathing = false

    /// The last of the first-run tips: there is a dub to hear now. See `DubTips`.
    private let playDubTip = DubPlayDubTip()

    init(pack: DubPack, library: DubPackLibrary) {
        self.pack = pack
        _viewModel = StateObject(wrappedValue: DubPackDetailViewModel(pack: pack, library: library))
    }

    /// The session the record and playback screens share. Its changes reach this screen
    /// through `viewModel`, which passes them on.
    private var session: DubSessionViewModel { viewModel.session }

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

                        if viewModel.videoNeedsReimport {
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

            if viewModel.isExporting {
                exportOverlay
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: $viewModel.showRecorder, onDismiss: { viewModel.recorderDidDismiss() }) {
            DubRecordView(session: session)
                .onAppear { viewModel.recorderDidAppear() }
        }
        .fullScreenCover(item: $viewModel.playbackMode) { mode in
            DubPlaybackView(session: session, mode: mode)
        }
        .dubShareNotice(isPresented: $viewModel.showShareNotice, pack: pack) {
            viewModel.confirmExport()
        }
        .overlay {
            if viewModel.showExportOptions {
                DubExportOptionsModal(
                    pack: pack,
                    line: viewModel.exportOptionsLine,
                    hasBoothFootage: session.hasAnyBoothTake,
                    runtime: { viewModel.runtime(of: $0) },
                    onExport: { cut, frame, includesBooth in
                        viewModel.configureExport(cut: cut, frame: frame, includesBooth: includesBooth)
                    },
                    onCancel: { viewModel.cancelExportOptions() }
                )
            }
        }
        .animation(.rsSmooth, value: viewModel.showExportOptions)
        .sheet(item: $viewModel.exportedURL) { url in
            DubShareSheet(url: url)
        }
        .alert(Strings.Main.Alert.errorTitle, isPresented: .init(
            get: { session.errorMessage != nil },
            set: { if !$0 { session.errorMessage = nil } }
        )) {
            Button(Strings.Main.Alert.ok, role: .cancel) { session.errorMessage = nil }
        } message: {
            Text(session.errorMessage ?? "")
        }
        .task { await viewModel.checkVideo() }
        .dubTipStyle()
        .advancesDubTips(past: 2, when: playDubTip)
        .onAppear { viewModel.onAppear() }
        #if DEBUG
        .task { await viewModel.runScreenshotTour() }
        #endif
        // Keyed on the preference, so switching scoring on from the library and coming
        // straight back marks what is already here rather than showing a half-empty panel.
        .task(id: scoring.isEnabled) { await viewModel.scoringDidChange() }
        .onDisappear { viewModel.onDisappear() }
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
                    "\(session.recordedCount)/\(pack.lines.count)"
                )
                slateDivider
                slateField(Strings.Dub.slateDuration, pack.formattedDuration)
                slateDivider
                // Only for a scene that has been filmed. An empty field on every other pack
                // would advertise a feature rather than report a fact.
                if session.hasAnyBoothTake {
                    slateField(
                        Strings.Booth.slug,
                        String(format: "%02d", session.boothSlugs.count)
                    )
                    slateDivider
                }
                if scoring.isEnabled {
                    slateField(
                        Strings.Dub.Score.slate,
                        session.sceneScore.recordedLines > 0
                            ? String(format: "%d", Int(session.sceneScore.overall.rounded()))
                            : "-",
                        tint: session.sceneScore.recordedLines > 0
                            ? session.sceneScore.grade.color
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
                score: session.sceneScore,
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
                    title: session.hasAnyTake ? Strings.Dub.continueRecording : Strings.Dub.record,
                    subtitle: session.currentLine?.character,
                    icon: "mic.fill",
                    dotCount: 0,
                    color: .rsRecord,
                    isEnabled: true,
                    recordingLevel: 0,
                    action: { viewModel.openRecorder() }
                )

                LargeActionButton(
                    title: Strings.Dub.playOriginal,
                    subtitle: pack.formattedDuration,
                    icon: "play.fill",
                    dotCount: 0,
                    color: .rsHighlight,
                    isEnabled: true,
                    recordingLevel: 0,
                    action: { viewModel.playOriginal() }
                )

                LargeActionButton(
                    title: Strings.Dub.playMyDub,
                    subtitle: session.hasAnyTake ? nil : Strings.Dub.noTakesYet,
                    icon: "person.wave.2.fill",
                    dotCount: 0,
                    color: .rsGood,
                    isEnabled: session.hasAnyTake,
                    recordingLevel: 0,
                    action: {
                        playDubTip.invalidate(reason: .actionPerformed)
                        viewModel.playMyDub()
                    }
                )
                .popoverTip(playDubTip, arrowEdge: .bottom)

                // Through the notice, never straight to the export: the file about to be
                // made is the user's voice over someone else's picture, and this is the
                // only moment where saying so is about something concrete.
                BigButton(
                    title: Strings.Dub.export,
                    icon: "square.and.arrow.up",
                    color: .rsTextPrimary,
                    action: { viewModel.beginExport(line: nil) },
                    isEnabled: session.hasAnyTake && !viewModel.isExporting,
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
                        viewModel.openRecorder(at: line)
                    } label: {
                        DubLineRow(
                            line: line,
                            isRecorded: session.isRecorded(line),
                            score: session.score(for: line),
                            hasBoothTake: session.hasBoothTake(line),
                            characterColor: DubCharacterStyle.color(
                                for: line.character,
                                in: pack.characters
                            )
                        )
                    }
                    .buttonStyle(.plain)
                    // A long press rather than a button on the row: tapping a line means
                    // "record it", and that is the thing someone reaches for a hundred times
                    // more often than sharing one.
                    .contextMenu {
                        if session.isRecorded(line) {
                            Button {
                                viewModel.beginExport(line: line)
                            } label: {
                                Label(Strings.Booth.shareLine, systemImage: "square.and.arrow.up")
                            }
                        }
                    }

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

// MARK: - Presentation Helpers

extension DubPlaybackMode: Identifiable {
    var id: String { rawValue }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
