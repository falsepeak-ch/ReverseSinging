//
//  DubExportOptionsModal.swift
//  ReverseSinging
//
//  Which stretch of the film leaves, and how the booth sits in it
//

import SwiftUI
import AVFoundation
import DubCompositing
import DubloonFoundation

/// The two choices an export now has: the cut, and the booth frame.
///
/// **The preview is drawn from `DubBoothLayout`, not from a picture of it.** The same
/// arithmetic that positions the real render positions these rectangles, so the diagram cannot
/// drift away from what the file turns out to be — which is exactly what a hand-drawn preview
/// of a compositing option does the first time the layout changes.
struct DubExportOptionsModal: View {

    let onExport: (DubCut, DubBoothFrame, Bool) -> Void
    let onCancel: () -> Void

    @StateObject private var viewModel: DubExportOptionsViewModel
    @State private var showsAdvanced = false

    init(
        pack: DubPack,
        line: DubLine? = nil,
        hasBoothFootage: Bool,
        runtime: @escaping (DubCut) -> TimeInterval,
        onExport: @escaping (DubCut, DubBoothFrame, Bool) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onExport = onExport
        self.onCancel = onCancel
        _viewModel = StateObject(wrappedValue: DubExportOptionsViewModel(
            pack: pack,
            line: line,
            hasBoothFootage: hasBoothFootage,
            runtime: runtime
        ))
    }

    var body: some View {
        ZStack {
            backdrop

            panel
                .padding(.horizontal, EditorMetrics.gutter)
                .padding(.vertical, 20)
                .transition(.opacity)
        }
        .onAppear { viewModel.onAppear() }
        .task { await viewModel.loadSceneSize() }
        .task { await viewModel.loadBoothStill() }
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

                if let line = viewModel.line { lineIdentity(line) }

                framePicker

                advanced

                slate

                VStack(spacing: 8) {
                    BigButton(
                        title: viewModel.line == nil ? Strings.Booth.exportConfirm : Strings.Booth.exportLineConfirm,
                        icon: "square.and.arrow.up",
                        color: .rsTextPrimary,
                        action: { onExport(viewModel.cut, viewModel.frame, viewModel.exportsBooth) },
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
                Text(viewModel.pack.title)
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
            frame: viewModel.frame,
            sceneDisplaySize: viewModel.sceneDisplaySize,
            boothDisplaySize: DubExportOptionsViewModel.boothDisplaySize
        )
        // What the scene actually gets: the band it shares with the booth, or the whole
        // picture area when there is no booth in the file.
        let sceneRect = viewModel.showsBooth ? layout.sceneRect : layout.sceneRectAlone

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
                        image: viewModel.sceneStillURL.map { DubStillImage(url: $0) },
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

                    if let boothRect = layout.boothRect, viewModel.showsBooth {
                        previewPane(
                            image: viewModel.boothStill.map { still in
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
        .animation(.easeInOut(duration: 0.18), value: viewModel.frame)
        .animation(.easeInOut(duration: 0.18), value: viewModel.includesBooth)
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
                segment(Strings.Booth.cutFullScene, isSelected: viewModel.cut == .fullScene) {
                    viewModel.cut = .fullScene
                }

                Rectangle()
                    .fill(Color.rsStroke)
                    .frame(width: EditorMetrics.hairline)

                segment(Strings.Booth.cutSessionReel, isSelected: viewModel.cut == .sessionReel) {
                    viewModel.cut = .sessionReel
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
                .fill(DubCharacterStyle.color(for: line.character, in: viewModel.pack.characters))
                .frame(width: 3, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                DubCharacterPlate(
                    character: line.character,
                    color: DubCharacterStyle.color(for: line.character, in: viewModel.pack.characters)
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

            if !viewModel.hasBoothFootage {
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
                    if viewModel.line == nil { cutPicker }

                    if viewModel.frame.isVertical { boothSwitch }

                    if viewModel.hasBoothFootage {
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
            Toggle(isOn: $viewModel.includesBooth) {
                Text(Strings.Booth.includeBooth)
                    .font(.rsBodySmall)
                    .foregroundColor(.rsTextPrimary)
            }
            .toggleStyle(SwitchToggleStyle(tint: .rsHighlight))
            .disabled(!viewModel.hasBoothFootage)
            .opacity(viewModel.hasBoothFootage ? 1 : 0.55)

            Text(Strings.Booth.includeBoothDetail)
                .font(.rsCaptionSmall)
                .foregroundColor(.rsTextTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 2)
    }

    private func frameTile(_ option: DubBoothFrame) -> some View {
        let isSelected = viewModel.frame == option
        let isAvailable = viewModel.isAvailable(option)

        return Button {
            HapticManager.shared.light()
            viewModel.frame = option
        } label: {
            VStack(spacing: 6) {
                FrameDiagram(
                    frame: option,
                    sceneDisplaySize: viewModel.sceneDisplaySize,
                    showsBooth: viewModel.showsBooth(in: option)
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
            slateField(Strings.Booth.runtime, viewModel.runtimeText)

            Rectangle()
                .fill(Color.rsStroke)
                .frame(width: EditorMetrics.hairline, height: 22)

            slateField(Strings.Booth.shape, viewModel.shapeLabel)
        }
        .frame(height: 44)
        .editorPanel(.rsSurface2)
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
