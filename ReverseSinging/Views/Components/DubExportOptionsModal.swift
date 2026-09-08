//
//  DubExportOptionsModal.swift
//  ReverseSinging
//
//  Which stretch of the film leaves, and how the booth sits in it
//

import SwiftUI

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

    let onExport: (DubCut, DubBoothFrame) -> Void
    let onCancel: () -> Void

    @State private var cut: DubCut
    @State private var frame: DubBoothFrame

    init(
        pack: DubPack,
        line: DubLine? = nil,
        hasBoothFootage: Bool,
        runtime: @escaping (DubCut) -> TimeInterval,
        onExport: @escaping (DubCut, DubBoothFrame) -> Void,
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

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Strings.Booth.exportTitle)
                        .font(.rsHeadingSmall)
                        .foregroundColor(.rsTextPrimary)

                    Text(line == nil ? Strings.Booth.exportSubtitle : Strings.Booth.exportLineSubtitle)
                        .font(.rsBodySmall)
                        .foregroundColor(.rsTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                preview

                if let line {
                    lineIdentity(line)
                } else {
                    cutPicker
                }

                framePicker

                slate

                VStack(spacing: 8) {
                    BigButton(
                        title: line == nil ? Strings.Booth.exportConfirm : Strings.Booth.exportLineConfirm,
                        icon: "square.and.arrow.up",
                        color: .rsTextPrimary,
                        action: { onExport(cut, frame) },
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
            sceneDisplaySize: CGSize(width: 1280, height: 720),
            boothDisplaySize: CGSize(width: 720, height: 1280)
        )

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

                    previewLabel(Strings.Dub.original, tint: .rsTextSecondary)
                        .frame(
                            width: layout.sceneRect.width * scale,
                            height: layout.sceneRect.height * scale
                        )
                        .background(Color.rsSurface2)
                        .offset(
                            x: layout.sceneRect.minX * scale,
                            y: layout.sceneRect.minY * scale
                        )

                    if let boothRect = layout.boothRect {
                        previewLabel(Strings.Booth.slug, tint: .rsHighlight)
                            .frame(
                                width: boothRect.width * scale,
                                height: boothRect.height * scale
                            )
                            .background(Color.rsHighlight.opacity(0.22))
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

            HStack(spacing: 8) {
                ForEach(DubBoothFrame.allCases) { option in
                    frameTile(option)
                }
            }

            Text(hasBoothFootage ? Strings.Booth.stackedNote : Strings.Booth.noFootage)
                .font(.rsCaptionSmall)
                .foregroundColor(.rsTextTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .opacity(hasBoothFootage ? 1 : 0.55)
        .disabled(!hasBoothFootage)
    }

    private func frameTile(_ option: DubBoothFrame) -> some View {
        let isSelected = frame == option

        return Button {
            HapticManager.shared.light()
            frame = option
        } label: {
            VStack(spacing: 6) {
                FrameDiagram(frame: option)
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
        .accessibilityLabel(name(for: option))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func name(for option: DubBoothFrame) -> String {
        switch option {
        case .off: return Strings.Booth.frameOff
        case .corner: return Strings.Booth.frameCorner
        case .stacked: return Strings.Booth.frameStacked
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

            slateField(Strings.Booth.shape, frame == .stacked ? "9:16" : "16:9")
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

    var body: some View {
        let layout = DubBoothLayout.make(
            frame: frame,
            sceneDisplaySize: CGSize(width: 1280, height: 720),
            boothDisplaySize: CGSize(width: 720, height: 1280)
        )

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
                    .frame(
                        width: layout.sceneRect.width * scale,
                        height: layout.sceneRect.height * scale
                    )
                    .offset(x: layout.sceneRect.minX * scale, y: layout.sceneRect.minY * scale)

                if let boothRect = layout.boothRect {
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
