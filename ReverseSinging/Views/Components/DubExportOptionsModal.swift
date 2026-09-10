//
//  DubExportOptionsModal.swift
//  ReverseSinging
//
//  Which stretch of the film leaves, and how the booth sits in it
//

import SwiftUI
import AVFoundation

/// The two choices an export now has: the cut, and the booth frame.
///
/// **The preview is drawn from `DubBoothLayout`, not from a picture of it.** The same
/// arithmetic that positions the real render positions these rectangles, so the diagram cannot
/// drift away from what the file turns out to be — which is exactly what a hand-drawn preview
/// of a compositing option does the first time the layout changes.
struct DubExportOptionsModal: View {

    let pack: DubPack
    /// Non-nil when this is one line's own export, reached from its row in the list.
    let line: DubLine?
    /// Whether there is any booth footage to composite at all.
    let hasBoothFootage: Bool
    /// How long the finished file runs, for the selected cut.
    let runtime: (DubCut) -> TimeInterval

    let onExport: (DubCut, DubBoothFrame, Bool) -> Void
    let onCancel: () -> Void

    @State private var cut: DubCut
    @State private var frame: DubBoothFrame
    /// Whether the performer's own footage goes into the file. Only the vertical frames can
    /// be rendered without it, so only they show the switch.
    @State private var includesBooth: Bool
    /// The scene picture's shape, read from the pack's own video. Nil until it has loaded, and
    /// for packs that have no video and are exported as a slideshow.
    @State private var sceneSize: CGSize?
    @State private var showsAdvanced = false
    /// A frame lifted out of one of the booth clips, so the diagram can show the performer
    /// rather than a labelled rectangle. Nil for a scene that was never filmed.
    @State private var boothStill: UIImage?

    init(
        pack: DubPack,
        line: DubLine? = nil,
        hasBoothFootage: Bool,
        runtime: @escaping (DubCut) -> TimeInterval,
        onExport: @escaping (DubCut, DubBoothFrame, Bool) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.pack = pack
        self.line = line
        self.hasBoothFootage = hasBoothFootage
        self.runtime = runtime
        self.onExport = onExport
        self.onCancel = onCancel

        _cut = State(initialValue: line.map { DubCut.line($0.slug) } ?? .fullScene)
        // A single line is four seconds, and four seconds is a vertical post. The whole scene
        // is not, so it keeps the shape it has always exported in.
        _frame = State(initialValue: hasBoothFootage ? (line == nil ? .corner : .stacked) : .off)
        _includesBooth = State(initialValue: hasBoothFootage)
    }

    var body: some View {
        ZStack {
            backdrop

            panel
                .padding(.horizontal, EditorMetrics.gutter)
                .padding(.vertical, 20)
                .transition(.opacity)
        }
        .onAppear { AnalyticsManager.shared.trackScreenViewed(screenName: "DubExportOptions") }
        .task {
            sceneSize = await DubBoothComposer.sceneDisplaySize(of: pack)
        }
        .task {
            boothStill = await Self.boothStill(in: pack)
        }
    }

    /// A frame from the first booth clip this pack has, for the diagram.
    ///
    /// Half a second in rather than at zero: the first frame of a take is the performer still
    /// arranging their face, which is nobody's idea of a thumbnail.
    private static func boothStill(in pack: DubPack) async -> UIImage? {
        guard let line = pack.lines.first(where: { pack.hasBoothTake(for: $0) }) else { return nil }

        let asset = AVURLAsset(url: pack.boothTakeURL(for: line))
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 240, height: 240)

        guard let image = try? await generator.image(at: CMTime(seconds: 0.5, preferredTimescale: 600)).image
        else { return nil }

        return UIImage(cgImage: image)
    }

    /// The booth's own shape, for laying out the diagram before any footage is opened. Every
    /// clip `BoothRecorder` writes is portrait; the exact numbers only move the inset by a
    /// hair, and the render reads the real ones.
    private static let boothDisplaySize = CGSize(width: 720, height: 1280)

    /// The shape the export is laid out around: the pack's own video, or the 16:9 slideshow
    /// that stands in for a pack that has none.
    private var sceneDisplaySize: CGSize {
        sceneSize ?? CGSize(width: 1280, height: 720)
    }

    /// Whether the performer will actually be in the file.
    private var showsBooth: Bool {
        hasBoothFootage && (includesBooth || !frame.isVertical)
    }

    private var backdrop: some View {
        Color.rsSurface0
            .opacity(0.88)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture { cancel() }
            .accessibilityHidden(true)
    }

    // MARK: - Panel

    private var panel: some View {
        ViewThatFits(in: .vertical) {
            content
            ScrollView { content }
                .scrollBounceBehavior(.basedOnSize)
        }
        .editorPanel(.rsSurface1, radius: EditorMetrics.radiusLarge)
        .frame(maxWidth: 420)
    }

    private var content: some View {
        VStack(spacing: 0) {
            titleBar

            VStack(alignment: .leading, spacing: 16) {
                Text(Strings.Booth.exportTitle)
                    .font(.rsHeadingSmall)
                    .foregroundColor(.rsTextPrimary)

                // The preview says what the other choices used to have to explain, now that
                // it is made of the actual scene and the actual face rather than two grey
                // rectangles with words in them.
                preview

                if let line { lineIdentity(line) }

                framePicker

                advanced

                slate

                VStack(spacing: 8) {
                    BigButton(
                        title: line == nil ? Strings.Booth.exportConfirm : Strings.Booth.exportLineConfirm,
                        icon: "square.and.arrow.up",
                        color: .rsTextPrimary,
                        action: { onExport(cut, frame, includesBooth && hasBoothFootage) },
                        style: .primary,
                        textFont: .rsButtonMedium
                    )

                    Text(Strings.Booth.exportNotice)
                        .font(.rsCaptionSmall)
                        .foregroundColor(.rsTextTertiary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(EditorMetrics.gutter)
        }
    }

    private var titleBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text(pack.title)
                    .editorLabelStyle(.rsTextSecondary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                EditorToolbarButton(icon: "xmark", label: Strings.DubGate.close, action: cancel)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            EditorRule()
        }
    }

    // MARK: - Preview

    /// The output frame, at the shape it will actually be, with each picture in its place.
    private var preview: some View {
        let layout = DubBoothLayout.make(
            frame: frame,
            sceneDisplaySize: sceneDisplaySize,
            boothDisplaySize: Self.boothDisplaySize
        )
        // What the scene actually gets: the band it shares with the booth, or the whole
        // picture area when there is no booth in the file.
        let sceneRect = showsBooth ? layout.sceneRect : layout.sceneRectAlone

        return VStack(spacing: 0) {
            GeometryReader { geometry in
                let stage = geometry.size
                let scale = min(
                    stage.width / layout.renderSize.width,
                    stage.height / layout.renderSize.height
                )
                let size = CGSize(
                    width: layout.renderSize.width * scale,
                    height: layout.renderSize.height * scale
                )

                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .fill(Color.rsSurface3)
                        .frame(width: size.width, height: size.height)

                    previewPane(
                        image: sceneStillURL.map { DubStillImage(url: $0) },
                        label: Strings.Dub.original,
                        tint: .rsTextSecondary,
                        fill: Color.rsSurface2
                    )
                    .frame(width: sceneRect.width * scale, height: sceneRect.height * scale)
                    .offset(x: sceneRect.minX * scale, y: sceneRect.minY * scale)

                    if let waveRect = layout.waveRect {
                        previewWave
                            .frame(
                                width: waveRect.width * scale,
                                height: waveRect.height * scale
                            )
                            .background(Color.rsSurface1)
                            .offset(x: waveRect.minX * scale, y: waveRect.minY * scale)
                    }

                    if let boothRect = layout.boothRect, showsBooth {
                        previewPane(
                            image: boothStill.map { still in
                                Image(uiImage: still).resizable().aspectRatio(contentMode: .fill)
                            },
                            label: Strings.Booth.slug,
                            tint: .rsHighlight,
                            fill: Color.rsHighlight.opacity(0.22)
                        )
                        .frame(width: boothRect.width * scale, height: boothRect.height * scale)
                        .overlay(
                            Rectangle().strokeBorder(
                                Color.rsHighlight.opacity(0.55),
                                lineWidth: EditorMetrics.hairline
                            )
                        )
                        .offset(x: boothRect.minX * scale, y: boothRect.minY * scale)
                    }
                }
                // Two frames, each doing one job: the first pins the stack to the render
                // size with a top-left origin, which is the space the layout's rects are in;
                // the second centres that stack in the stage.
                .frame(width: size.width, height: size.height, alignment: .topLeading)
                .frame(width: stage.width, height: stage.height, alignment: .center)
            }
            .frame(height: 168)
            .frame(maxWidth: .infinity)
            .background(Color.rsSurface0)
        }
        .editorPanel(.rsSurface0)
        .animation(.easeInOut(duration: 0.18), value: frame)
        .animation(.easeInOut(duration: 0.18), value: includesBooth)
    }

    /// A token waveform, so the strip in the diagram reads as the strip in the file rather
    /// than as another empty band.
    private var previewWave: some View {
        GeometryReader { geometry in
            let bars = max(1, Int(geometry.size.width / 4))
            HStack(alignment: .center, spacing: 1) {
                ForEach(0..<bars, id: \.self) { index in
                    Capsule()
                        .fill(Color.rsTextTertiary)
                        .frame(height: Self.previewBarHeights[index % Self.previewBarHeights.count] * geometry.size.height)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .padding(.horizontal, 3)
    }

    /// A fixed, unremarkable shape. A random one would redraw differently on every body pass.
    private static let previewBarHeights: [CGFloat] = [
        0.25, 0.55, 0.35, 0.75, 0.45, 0.9, 0.4, 0.6, 0.3, 0.7, 0.5, 0.35
    ]

    /// One pane of the diagram: the real picture where there is one, the old labelled block
    /// where there is not.
    ///
    /// A still rather than a moving preview on purpose — this is a diagram of a layout, and a
    /// pane playing footage would read as the export itself and invite people to wait for it
    /// to finish.
    private func previewPane<Content: View>(
        image: Content?,
        label: String,
        tint: Color,
        fill: Color
    ) -> some View {
        // The picture goes in an overlay rather than as a sibling in a stack. An aspect-fill
        // image is bigger than the space it is given, and as a stack child it sizes the stack
        // — which here meant the booth pane growing out of the diagram and over the title.
        fill
            .overlay { image }
            .clipped()
            // Dimmed a little, so the labels stay legible over a bright frame and the panes
            // still read as parts of a diagram rather than as the finished thing.
            .overlay { if image != nil { Color.rsSurface0.opacity(0.28) } }
            .overlay { previewLabel(label, tint: image == nil ? tint : .rsTextPrimary) }
    }

    /// The still that stands in for the scene: the line being exported when there is one,
    /// otherwise a frame from the middle of the film rather than its first, which on these
    /// packs is usually a title card.
    private var sceneStillURL: URL? {
        if let line { return pack.imageURL(for: line) }
        guard !pack.lines.isEmpty else { return nil }
        return pack.imageURL(for: pack.lines[pack.lines.count / 2])
    }

    private func previewLabel(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .tracking(1)
            .textCase(.uppercase)
            .foregroundColor(tint)
            // The corner inset is narrower than the word, and "BOOT / H" over two lines is
            // worse than no label at all.
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .allowsTightening(true)
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Cut

    private var cutPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            EditorSectionHeader(title: Strings.Booth.cut)

            HStack(spacing: 0) {
                segment(Strings.Booth.cutFullScene, isSelected: cut == .fullScene) {
                    cut = .fullScene
                }

                Rectangle()
                    .fill(Color.rsStroke)
                    .frame(width: EditorMetrics.hairline)

                segment(Strings.Booth.cutSessionReel, isSelected: cut == .sessionReel) {
                    cut = .sessionReel
                }
            }
            .frame(height: 36)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(Color.rsStroke, lineWidth: EditorMetrics.hairline)
            )

            Text(Strings.Booth.cutDetail)
                .font(.rsCaptionSmall)
                .foregroundColor(.rsTextTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func segment(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.shared.light()
            action()
        } label: {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? .rsTextPrimary : .rsTextSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(isSelected ? Color.rsSurface3 : Color.rsSurface2)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// The single-line case has no cut to choose, so this says what is going instead.
    private func lineIdentity(_ line: DubLine) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Rectangle()
                .fill(DubCharacterStyle.color(for: line.character, in: pack.characters))
                .frame(width: 3, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                DubCharacterPlate(
                    character: line.character,
                    color: DubCharacterStyle.color(for: line.character, in: pack.characters)
                )

                Text(line.caption)
                    .font(.rsBodySmall)
                    .foregroundColor(.rsTextSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Booth Frame

    private var framePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            EditorSectionHeader(title: Strings.Booth.frameSection)

            HStack(spacing: 6) {
                ForEach(DubBoothFrame.allCases) { option in
                    frameTile(option)
                }
            }

            if !hasBoothFootage {
                Text(Strings.Booth.noFootage)
                    .font(.rsCaptionSmall)
                    .foregroundColor(.rsTextTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Advanced

    /// Everything that has a right answer for almost everybody.
    ///
    /// The cut is the whole scene, the booth goes in when there is booth footage, and the
    /// runtime is whatever it is. Left on the surface, three sections of explanatory prose
    /// were the first thing anyone met on the way to a button they had already decided to
    /// press. They are still one tap away, and the panel remembers nothing: it opens closed
    /// every time, because a sheet that reopens mid-scroll into a section nobody asked for is
    /// the problem this is fixing.
    private var advanced: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                HapticManager.shared.light()
                withAnimation(.easeInOut(duration: 0.2)) { showsAdvanced.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Text(Strings.Booth.advanced)
                        .editorLabelStyle(.rsTextSecondary)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.rsTextTertiary)
                        .rotationEffect(.degrees(showsAdvanced ? 0 : -90))

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showsAdvanced {
                VStack(alignment: .leading, spacing: 16) {
                    if line == nil { cutPicker }

                    if frame.isVertical { boothSwitch }

                    if hasBoothFootage {
                        Text(Strings.Booth.stackedNote)
                            .font(.rsCaptionSmall)
                            .foregroundColor(.rsTextTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 12)
                .transition(.opacity)
            }
        }
    }

    /// Whether the performer is in the vertical frame at all.
    ///
    /// Only shown for the frames that stand up without the booth: a corner inset or a split
    /// with the face taken out is not a shape, it is `off` with extra steps. Forced off, and
    /// explained, when the scene has no footage to include.
    private var boothSwitch: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: $includesBooth) {
                Text(Strings.Booth.includeBooth)
                    .font(.rsBodySmall)
                    .foregroundColor(.rsTextPrimary)
            }
            .toggleStyle(SwitchToggleStyle(tint: .rsHighlight))
            .disabled(!hasBoothFootage)
            .opacity(hasBoothFootage ? 1 : 0.55)

            Text(Strings.Booth.includeBoothDetail)
                .font(.rsCaptionSmall)
                .foregroundColor(.rsTextTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 2)
    }

    /// Whether a frame can be picked at all. Without booth footage the vertical frames are
    /// still worth having — they reshape the export and draw the waveform strip — but the
    /// ones that exist only to place a face are not.
    private func isAvailable(_ option: DubBoothFrame) -> Bool {
        hasBoothFootage || !option.needsCompositing || option.isVertical
    }

    private func frameTile(_ option: DubBoothFrame) -> some View {
        let isSelected = frame == option
        let isAvailable = isAvailable(option)

        return Button {
            HapticManager.shared.light()
            frame = option
        } label: {
            VStack(spacing: 6) {
                FrameDiagram(
                    frame: option,
                    sceneDisplaySize: sceneDisplaySize,
                    showsBooth: hasBoothFootage && (includesBooth || !option.isVertical)
                )
                .frame(height: 34)

                Text(name(for: option))
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundColor(isSelected ? .rsTextPrimary : .rsTextTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isSelected ? Color.rsSurface3 : Color.rsSurface2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.rsStrokeStrong : Color.rsStroke,
                        lineWidth: EditorMetrics.hairline
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isAvailable ? 1 : 0.4)
        .disabled(!isAvailable)
        .accessibilityLabel(name(for: option))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func name(for option: DubBoothFrame) -> String {
        switch option {
        case .off: return Strings.Booth.frameOff
        case .corner: return Strings.Booth.frameCorner
        case .stacked: return Strings.Booth.frameStacked
        case .reaction: return Strings.Booth.frameReaction
        case .split: return Strings.Booth.frameSplit
        }
    }

    // MARK: - Slate

    /// What comes out, in the same camera-report style the scene's own facts are set in.
    private var slate: some View {
        HStack(spacing: 0) {
            slateField(Strings.Booth.runtime, runtime(cut).rsClock)

            Rectangle()
                .fill(Color.rsStroke)
                .frame(width: EditorMetrics.hairline, height: 22)

            slateField(Strings.Booth.shape, shapeLabel)
        }
        .frame(height: 44)
        .editorPanel(.rsSurface2)
    }

    /// The shape the file really comes out at.
    ///
    /// The vertical frames render to a fixed 9:16 canvas. Every other frame keeps the scene's
    /// own shape, which is whatever the pack ships — a 4:3 short from 1951 as readily as a
    /// 16:9 one — so this reads it rather than assuming.
    private var shapeLabel: String {
        DubBoothLayout.make(
            frame: frame,
            sceneDisplaySize: sceneDisplaySize,
            boothDisplaySize: Self.boothDisplaySize
        ).renderSize.rsAspectLabel
    }

    private func slateField(_ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(label).editorLabelStyle()
            Text(value)
                .font(.rsTimecodeSmall)
                .foregroundColor(.rsTextPrimary)
        }
        .frame(maxWidth: .infinity)
    }

    private func cancel() {
        HapticManager.shared.light()
        onCancel()
    }
}

// MARK: - Frame Diagram

/// The little picture on a frame tile, drawn from the layout rather than described twice.
private struct FrameDiagram: View {
    let frame: DubBoothFrame
    let sceneDisplaySize: CGSize
    /// Whether the tile should show a booth band. A frame rendered without the performer is a
    /// different shape on screen, and the tile is what the user picks from.
    let showsBooth: Bool

    var body: some View {
        let layout = DubBoothLayout.make(
            frame: frame,
            sceneDisplaySize: sceneDisplaySize,
            boothDisplaySize: CGSize(width: 720, height: 1280)
        )
        let sceneRect = showsBooth ? layout.sceneRect : layout.sceneRectAlone

        GeometryReader { geometry in
            let scale = min(
                geometry.size.width / layout.renderSize.width,
                geometry.size.height / layout.renderSize.height
            )
            let size = CGSize(
                width: layout.renderSize.width * scale,
                height: layout.renderSize.height * scale
            )

            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Color.rsStrokeStrong)
                    .frame(width: sceneRect.width * scale, height: sceneRect.height * scale)
                    .offset(x: sceneRect.minX * scale, y: sceneRect.minY * scale)

                if let waveRect = layout.waveRect {
                    Rectangle()
                        .fill(Color.rsStroke)
                        .frame(width: waveRect.width * scale, height: waveRect.height * scale)
                        .offset(x: waveRect.minX * scale, y: waveRect.minY * scale)
                }

                if let boothRect = layout.boothRect, showsBooth {
                    Rectangle()
                        .fill(Color.rsTextSecondary)
                        .frame(width: boothRect.width * scale, height: boothRect.height * scale)
                        .offset(x: boothRect.minX * scale, y: boothRect.minY * scale)
                }
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
        }
        .accessibilityHidden(true)
    }
}
