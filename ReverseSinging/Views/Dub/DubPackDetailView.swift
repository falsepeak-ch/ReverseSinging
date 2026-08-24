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
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var showRecorder = false
    @State private var playbackMode: DubPlaybackMode?
    @State private var reelAngle: Double = 0

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
                        actions
                        lineList
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
        .onAppear {
            AnalyticsManager.shared.trackScreenViewed(screenName: "DubPackDetail")
        }
        .onDisappear {
            viewModel.stopEverything()
            library.reload()
        }
        .animation(.rsSpring, value: viewModel.isExporting)
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
                    "\(viewModel.recordedCount)/\(pack.lines.count)"
                )
                slateDivider
                slateField(Strings.Dub.slateDuration, pack.formattedDuration)
                slateDivider
                slateField(
                    Strings.Dub.slateCast,
                    String(format: "%02d", pack.characters.count)
                )
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

    private func slateField(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .editorLabelStyle()
            Text(value)
                .font(.rsTimecode)
                .foregroundColor(.rsTextPrimary)
        }
        .frame(maxWidth: .infinity)
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

                BigButton(
                    title: Strings.Dub.export,
                    icon: "square.and.arrow.up",
                    color: .rsTextPrimary,
                    action: { Task { await viewModel.export() } },
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

    // MARK: - Export Overlay

    private var exportOverlay: some View {
        ZStack {
            Color.rsSurface0.opacity(0.86)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                // The reel turns for as long as the render runs
                Image("film-reel")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .rotationEffect(.degrees(reelAngle))
                    .frame(maxWidth: .infinity)
                    .onAppear {
                        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                            reelAngle = 360
                        }
                    }
                    .onDisappear { reelAngle = 0 }

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
    let characterColor: Color

    var body: some View {
        HStack(spacing: 12) {
            Text(String(format: "%03d", line.index))
                .font(.rsTimecodeSmall)
                .foregroundColor(.rsTextTertiary)

            Rectangle()
                .fill(isRecorded ? Color.rsGood : Color.rsSurface3)
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

            Image(systemName: isRecorded ? "checkmark" : "circle.dashed")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isRecorded ? .rsGood : .rsTextTertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
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
