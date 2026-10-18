//
//  DubContentGateModal.swift
//  ReverseSinging
//
//  The gate in front of every dub import. The app hosts no scenes, so the first
//  thing it does is ask whether the user has their own; if not, it points at an
//  example third-party site and says plainly that the site is not ours and that
//  the rights are the user's problem. Answering costs one tap and nothing is
//  remembered, so the disclaimers and the pointer are in front of every import
//  rather than only the first.
//

import SwiftUI

struct DubContentGateModal: View {
    enum Step {
        case ask
        case download
        /// The numbered steps for getting a pack onto the phone (the game's third answer).
        case guide
    }

    let source: DubContentSource
    /// Called when the user confirms the packs are already on the device.
    let onReady: () -> Void
    /// Called when the user closes the modal without confirming.
    let onCancel: () -> Void

    @State private var step: Step = .ask
    @Environment(\.openURL) private var openURL

    var body: some View {
        EditorModal(
            title: Strings.Main.Mode.dubTitle,
            onBack: backAction,
            onClose: cancel
        ) {
            hero

            VStack(spacing: 10) {
                Text(title)
                    .font(.rsHeadingSmall)
                    .foregroundColor(.rsTextPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.rsBodySmall)
                    .foregroundColor(.rsTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if step == .guide {
                guideSteps
            }

            if step == .download || step == .guide {
                disclaimer
            }
        } phoneActions: {
            actions
        } macActions: {
            macActions
        }
        .animation(.rsSpring, value: step)
        .onAppear {
            AnalyticsManager.shared.trackDubGateShown()
        }
    }

    /// Only the download and guide steps have a step to go back to.
    private var backAction: (() -> Void)? {
        guard step != .ask else { return nil }
        return { goBack() }
    }

    /// The same two answers as on the iPhone, as the Mac footer's buttons: the one that moves
    /// on is the default.
    @ViewBuilder
    private var macActions: some View {
        switch step {
        case .ask:
            Button(Strings.DubGate.askNeedDownload, action: showDownloadStep)
                .platformGlassButton()
            Button(Strings.DubGate.askConfirm, action: confirmOwnership)
                .keyboardShortcut(.defaultAction)
                .platformProminentButton()
        case .download, .guide:
            Button(String(format: Strings.DubGate.downloadOpen, source.name), action: openSource)
                .keyboardShortcut(.defaultAction)
                .platformProminentButton()
        }
    }

    private var hero: some View {
        Image(GameArtName.object(step == .ask ? "movies" : "download"))
            .resizable()
            .scaledToFit()
            .frame(width: 88, height: 88)
            .accessibilityHidden(true)
    }

    // MARK: - Copy

    private var title: String {
        switch step {
        case .ask: return Strings.DubGate.askTitle
        case .download: return Strings.DubGate.downloadTitle
        case .guide: return Strings.DubGuide.title
        }
    }

    private var message: String {
        switch step {
        case .ask: return Strings.DubGate.askMessage
        case .download: return Strings.DubGate.downloadMessage
        case .guide: return Strings.DubGuide.intro
        }
    }

    // MARK: - Disclaimer

    private var disclaimer: some View {
        VStack(alignment: .leading, spacing: 10) {
            disclaimerRow(
                icon: "link",
                tint: .rsTextTertiary,
                text: String(format: Strings.DubGate.disclaimerNotAffiliated, source.host)
            )

            disclaimerRow(
                icon: "exclamationmark.triangle.fill",
                tint: .rsCaution,
                text: Strings.DubGate.disclaimerResponsibility
            )
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .editorPanel(.rsSurface2)
    }

    private func disclaimerRow(icon: String, tint: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 14)

            Text(text)
                .font(.rsMeta)
                .foregroundColor(.rsTextSecondary)
                .multilineTextAlignment(.leading)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private var actions: some View {
        switch step {
        case .ask:
            VStack(spacing: 10) {
                BigButton(
                    title: Strings.DubGate.askConfirm,
                    icon: "checkmark",
                    color: .rsHighlight,
                    action: confirmOwnership,
                    style: .primary,
                    textFont: .rsButtonMedium
                )

                BigButton(
                    title: Strings.DubGate.askNeedDownload,
                    icon: "arrow.down",
                    color: .rsHighlight,
                    action: showDownloadStep,
                    style: .secondary,
                    textFont: .rsButtonMedium
                )

                #if DUBLOON_GAME
                // The whole way, step by step, for whoever has never got a pack before.
                BigButton(
                    title: NSLocalizedString("game.dubGate.showSteps", tableName: "Game", comment: "The import gate's third answer, which opens the numbered steps for getting a scene"),
                    icon: "list.number",
                    color: .rsHighlight,
                    action: showGuideStep,
                    style: .secondary,
                    textFont: .rsButtonMedium
                )
                #endif
            }
        case .guide:
            VStack(spacing: 10) {
                BigButton(
                    title: String(format: Strings.DubGate.downloadOpen, source.name),
                    icon: "arrow.up.right",
                    color: .rsHighlight,
                    action: openSource,
                    style: .primary,
                    textFont: .rsButtonMedium
                )
                BigButton(
                    title: Strings.Dub.importPack,
                    icon: "square.and.arrow.down",
                    color: .rsHighlight,
                    action: confirmOwnership,
                    style: .secondary,
                    textFont: .rsButtonMedium
                )
            }
        case .download:
            BigButton(
                title: String(format: Strings.DubGate.downloadOpen, source.name),
                icon: "arrow.up.right",
                color: .rsHighlight,
                action: openSource,
                style: .primary,
                textFont: .rsButtonMedium
            )
        }
    }

    // MARK: - Behaviour

    private func confirmOwnership() {
        AnalyticsManager.shared.trackDubGateOwnershipConfirmed()
        onReady()
    }

    private func showDownloadStep() {
        AnalyticsManager.shared.trackDubGateDownloadHelpOpened()
        withAnimation(.rsSpring) { step = .download }
    }

    private func showGuideStep() {
        AnalyticsManager.shared.trackDubPackGuideOpened()
        withAnimation(.rsSpring) { step = .guide }
    }

    /// The guide's numbered steps, each a badge, a title and what to do. In the game the badges
    /// are the kit's chunky tokens, strung on a dotted path so the steps read as one way through.
    private var guideSteps: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(1...Strings.DubGuide.stepCount, id: \.self) { number in
                guideStep(number, isLast: number == Strings.DubGuide.stepCount)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func guideStep(_ number: Int, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                stepBadge(number)
                if !isLast {
                    stepConnector
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(Strings.DubGuide.stepTitle(number))
                    #if DUBLOON_GAME
                    .font(.gameDisplay(19))
                    .foregroundColor(.gameNavy)
                    #else
                    .font(.rsBodyMedium.weight(.bold))
                    .foregroundColor(.rsTextPrimary)
                    #endif
                Text(Strings.DubGuide.stepDetail(number))
                    .font(.rsBodySmall)
                    .foregroundColor(.rsTextSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 4)
            .padding(.bottom, isLast ? 0 : 16)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func stepBadge(_ number: Int) -> some View {
        #if DUBLOON_GAME
        // The last step is the way out when an import fails, so it wears the coral.
        let fill: Color = number == Strings.DubGuide.stepCount ? .gameCoral : .gameCyan
        ZStack {
            Circle().fill(Color.gameNavy).offset(y: 3)
            Circle().fill(fill)
                .overlay(Circle().strokeBorder(Color.gameNavy, lineWidth: 3))
                .overlay(alignment: .top) {
                    Capsule().fill(Color.white.opacity(0.45))
                        .frame(width: 14, height: 4)
                        .padding(.top, 6)
                }
            OutlinedText(text: "\(number)", size: 20, color: .white, outline: .gameNavy)
                .offset(y: 1)
        }
        .frame(width: 38, height: 38)
        .padding(.bottom, 3)
        .accessibilityHidden(true)
        #else
        Text("\(number)")
            .font(.rsBodySmall.weight(.heavy))
            .foregroundColor(.white)
            .frame(width: 28, height: 28)
            .background(Circle().fill(Color.rsHighlight))
            .accessibilityHidden(true)
        #endif
    }

    /// The dotted path from one badge down to the next.
    private var stepConnector: some View {
        Rectangle()
            .fill(.clear)
            .frame(width: 3)
            .frame(maxHeight: .infinity)
            .overlay {
                GeometryReader { proxy in
                    Path { path in
                        path.move(to: CGPoint(x: 1.5, y: 4))
                        path.addLine(to: CGPoint(x: 1.5, y: proxy.size.height - 2))
                    }
                    .stroke(Color.rsTextTertiary.opacity(0.7),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [0.1, 8]))
                }
            }
            .frame(minHeight: 14)
    }

    private func goBack() {
        withAnimation(.rsSpring) { step = .ask }
    }

    private func openSource() {
        AnalyticsManager.shared.trackDubGateExternalSourceOpened(source: source.id)
        openURL(source.url)
    }

    private func cancel() {
        onCancel()
    }
}

// MARK: - Presentation

private struct DubContentGateModifier: ViewModifier {
    @Binding var isPresented: Bool
    let source: DubContentSource
    let onReady: () -> Void

    func body(content: Content) -> some View {
        content.editorModal(isPresented: $isPresented) {
            DubContentGateModal(
                source: source,
                onReady: {
                    isPresented = false
                    onReady()
                },
                onCancel: {
                    isPresented = false
                }
            )
        }
    }
}

extension View {
    /// Presents the "do you already have your movies?" gate over this view.
    ///
    /// - Parameters:
    ///   - isPresented: Binding driving the modal.
    ///   - source: Example third-party site suggested when the user has no packs yet.
    ///   - onReady: Called once the user confirms the packs are on the device.
    func dubContentGate(
        isPresented: Binding<Bool>,
        source: DubContentSource = .example,
        onReady: @escaping () -> Void
    ) -> some View {
        modifier(DubContentGateModifier(isPresented: isPresented, source: source, onReady: onReady))
    }
}

// MARK: - Previews

#Preview("Gate") {
    ZStack {
        Color.rsSurface0.ignoresSafeArea()
        DubContentGateModal(source: .example, onReady: {}, onCancel: {})
    }
    .preferredColorScheme(.dark)
}
