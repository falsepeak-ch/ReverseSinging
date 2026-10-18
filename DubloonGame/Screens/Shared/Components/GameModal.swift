//
//  GameModal.swift
//  DubloonGame
//
//  The frame the shared modals sit in when they appear in the game.
//

import SwiftUI

/// A modal as the game draws it: an ivory card with the kit's navy outline and lip, its title
/// on a navy plaque across the top edge, a round close key on the corner, and the modal's own
/// buttons under its content.
///
/// The shared modals (`EditorModal`) are written for Dubloon's studio look; in the game they
/// keep their content and behaviour and swap their frame for this one. The content is drawn
/// with the light colour tokens, so the studio's text reads dark on the ivory card.
struct GameModalFrame<Content: View, Actions: View>: View {
    let title: String
    var onBack: (() -> Void)?
    /// Nil for a modal with no way out but its own button, such as the microphone explanation.
    let onClose: (() -> Void)?
    @ViewBuilder var content: () -> Content
    @ViewBuilder var actions: () -> Actions

    @State private var contentHeight: CGFloat = 0
    @State private var isIn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.gameNavy
                .opacity(0.72)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onClose?() }
                .accessibilityHidden(true)

            card
                .frame(maxWidth: 400)
                .padding(.horizontal, 20)
                .padding(.top, 44)
                .padding(.bottom, 24)
                .scaleEffect(isIn ? 1 : 0.8)
                .opacity(isIn ? 1 : 0)
        }
        .onAppear {
            guard !reduceMotion else { isIn = true; return }
            GameSFX.play(.pop)
            withAnimation(.spring(response: 0.38, dampingFraction: 0.66)) { isIn = true }
        }
        .accessibilityAddTraits(.isModal)
    }

    private var card: some View {
        VStack(spacing: 0) {
            // Room for the plaque, which hangs half over the card's top edge.
            Color.clear.frame(height: 30)

            ScrollView {
                VStack(spacing: 18) {
                    content()
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 10)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
            .frame(maxHeight: contentHeight)

            actions()
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 18)
        }
        // The studio's tokens in their light set: dark text on the ivory card.
        .environment(\.colorScheme, .light)
        .gameCard(radius: 28, lip: 7)
        .overlay(alignment: .top) { plaque.offset(y: -26) }
        .overlay(alignment: .topTrailing) {
            if let onClose {
                GameRoundButton(symbol: "xmark", label: Strings.DubGate.close, diameter: 44) {
                    onClose()
                }
                .offset(x: 12, y: -18)
            }
        }
        .overlay(alignment: .topLeading) {
            if let onBack {
                GameRoundButton(symbol: "chevron.backward", label: Strings.DubGate.downloadBack, diameter: 44, action: onBack)
                    .offset(x: -12, y: -18)
            }
        }
    }

    /// The title on a navy plaque with a cyan rim, like the show's segment cards.
    private var plaque: some View {
        OutlinedText(text: title.uppercased(), size: 20, color: .gameCyan, outline: .gameNavy)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 18)
            .padding(.vertical, 4)
            .background {
                Capsule().fill(Color.gameNavy)
                    .overlay(Capsule().strokeBorder(Color.gameCyan, lineWidth: 2.5).padding(3))
            }
            .padding(.horizontal, 60)
            .accessibilityAddTraits(.isHeader)
    }
}

/// The game's version of a full-width modal button: the kit's pill, cyan for the main action,
/// ivory for the others, coral for a destructive one.
struct GameModalButton: View {
    enum Kind { case primary, secondary, destructive }

    let title: String
    var icon: String?
    var kind: Kind = .primary
    var isEnabled = true
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button {
            guard isEnabled, !isLoading else { return }
            HapticManager.shared.medium()
            action()
        } label: {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView().tint(fill.gameIsLight ? .gameNavy : .white)
                } else if let icon {
                    Image(systemName: icon).font(.system(size: 18, weight: .heavy))
                }
                Text(title)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(GamePillButtonStyle(fill: fill, height: 56))
        .disabled(!isEnabled || isLoading)
        .opacity(isEnabled ? 1 : 0.5)
    }

    private var fill: Color {
        switch kind {
        case .primary: .gameCyan
        case .secondary: .gameIvory
        case .destructive: .gameCoral
        }
    }
}
