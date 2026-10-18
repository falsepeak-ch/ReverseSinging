//
//  GameUI.swift
//  DubloonGame
//
//  The game's SwiftUI parts, drawn like the kit: navy outlines, a lip under everything,
//  chunky rounded type.
//

import SwiftUI

// MARK: - Palette

extension Color {
    /// The control deck under every round: the pale cyan of the kit's glass.
    static let gameDeck = Color(gameHex: 0xD3F4FB)
    /// The kit's darker cyan, for lips and edges on cyan parts.
    static let gamePetrol = Color(gameHex: 0x1B7E9C)
    /// The take, on the comparison display.
    static let gameMagenta = Color(gameHex: 0xF23FD0)
    /// The playhead.
    static let gameRed = Color(gameHex: 0xFF3B30)
    static let gameGold = Color(gameHex: 0xFFC83D)
}

// MARK: - Compact screens

extension EnvironmentValues {
    /// True on a short phone (an iPhone SE), where a round's deck draws its display and its
    /// mic key smaller so the controls under them stay on screen.
    @Entry var gameCompactDeck = false
}

// MARK: - Outlined type

/// Display type with a navy outline and a lip under it, like the lettering on the kit.
struct OutlinedText: View {
    let text: String
    var size: CGFloat = 28
    var color: Color = .gameIvory
    var outline: Color = .gameNavy
    var lineWidth: CGFloat? = nil

    var body: some View {
        let w = lineWidth ?? max(size * 0.09, 2)
        let label = Text(text)
            .font(.gameDisplay(size))
            .multilineTextAlignment(.center)

        ZStack {
            // The lip, then the outline: copies of the line pushed out in eight directions.
            ForEach(0..<8, id: \.self) { i in
                let angle = Double(i) / 8 * 2 * .pi
                label.foregroundStyle(outline)
                    .offset(x: cos(angle) * w, y: sin(angle) * w + w * 0.9)
            }
            ForEach(0..<8, id: \.self) { i in
                let angle = Double(i) / 8 * 2 * .pi
                label.foregroundStyle(outline)
                    .offset(x: cos(angle) * w, y: sin(angle) * w)
            }
            label.foregroundStyle(color)
        }
        .padding(w)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

// MARK: - Cards

extension View {
    /// An ivory card with a navy outline and a lip, the shape of the kit's panels.
    func gameCard(fill: Color = .gameIvory, radius: CGFloat = 22, lip: CGFloat = 5) -> some View {
        background {
            ZStack {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color.gameNavy)
                    .offset(y: lip)
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.gameNavy, lineWidth: 3.5)
            }
        }
    }
}

// MARK: - Buttons

/// The kit's cyan pill: navy outline, a navy lip that the pill sinks into when pressed, and a
/// thin gloss along the top edge.
///
/// The label's colour is picked for contrast with the fill unless one is given: navy on the
/// light fills (cyan, gold, ivory), white on the dark ones (coral, red). The gloss stays above
/// the label so it never cuts through the letters.
struct GamePillButtonStyle: ButtonStyle {
    var fill: Color = .gameCyan
    var height: CGFloat = 60
    var text: Color? = nil

    private var label: Color { text ?? (fill.gameIsLight ? .gameNavy : .white) }

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let lip: CGFloat = 6
        let onDark = label == .white
        configuration.label
            .font(.gameDisplay(22))
            .foregroundStyle(label)
            .shadow(color: onDark ? Color.gameNavy.opacity(0.7) : .clear, radius: 0, x: 0, y: 2)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 24)
            .frame(minHeight: height)
            .background {
                ZStack {
                    Capsule().fill(Color.gameNavy).offset(y: lip)
                    Capsule().fill(fill)
                    Capsule()
                        .fill(.white.opacity(0.4))
                        .frame(height: 4)
                        .padding(.horizontal, height * 0.45)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .padding(.top, 6)
                    Capsule().strokeBorder(Color.gameNavy, lineWidth: 3.5)
                }
            }
            .offset(y: pressed ? lip * 0.7 : 0)
            .scaleEffect(pressed ? 0.97 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.55), value: pressed)
            .padding(.bottom, lip)
            .onChange(of: pressed) { _, down in if down { GameSFX.play(.tap) } }
    }
}

/// A round ivory key with a symbol, for back, listen, replay.
struct GameRoundButton: View {
    let symbol: String
    let label: String
    var diameter: CGFloat = 58
    var fill: Color = .gameIvory
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.shared.light()
            // Back makes no sound: it is pressed too often for one to be welcome.
            if symbol != "chevron.backward" { GameSFX.play(.tap) }
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: diameter * 0.38, weight: .heavy))
                .foregroundStyle(Color.gameNavy)
                .frame(width: diameter, height: diameter)
        }
        .buttonStyle(RoundKeyStyle(diameter: diameter, fill: fill))
        .accessibilityLabel(label)
    }

    private struct RoundKeyStyle: ButtonStyle {
        let diameter: CGFloat
        let fill: Color

        func makeBody(configuration: Configuration) -> some View {
            let pressed = configuration.isPressed
            configuration.label
                .background {
                    ZStack {
                        Circle().fill(Color.gameNavy).offset(y: 4)
                        Circle().fill(fill)
                        Circle().strokeBorder(Color.gameNavy, lineWidth: 3.5)
                    }
                }
                .offset(y: pressed ? 3 : 0)
                .animation(.spring(response: 0.16, dampingFraction: 0.5), value: pressed)
                .padding(.bottom, 4)
        }
    }
}

/// The big microphone key at the bottom of every round.
///
/// Glossy cyan at rest; red with a stop square while the mic is open, swelling with the voice;
/// a pulsing ring through the count-in, which a second press cancels.
struct GameMicButton: View {
    let isRecording: Bool
    let isCountingIn: Bool
    /// 0...1, how much of the take's time is used.
    let progress: Double
    let level: Float
    let isEnabled: Bool
    let action: () -> Void

    @State private var pulse = false
    @Environment(\.gameCompactDeck) private var compact

    private var keySize: CGSize { compact ? CGSize(width: 140, height: 74) : CGSize(width: 168, height: 92) }
    private var ringSize: CGSize { CGSize(width: keySize.width + 16, height: keySize.height + 16) }

    var body: some View {
        Button {
            HapticManager.shared.medium()
            action()
        } label: {
            ZStack {
                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: compact ? 30 : 38, weight: .heavy))
                    .foregroundStyle(.white)
                    .shadow(color: .gameNavy, radius: 0, x: 0, y: 3)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: keySize.width, height: keySize.height)
        }
        .buttonStyle(MicKeyStyle(fill: isRecording ? .gameRed : .gameCyan, glow: isRecording ? CGFloat(level) : 0))
        .overlay {
            // Time left in the take, around the key.
            if isRecording {
                Capsule()
                    .trim(from: 0, to: progress)
                    .stroke(Color.gameGold, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: ringSize.width, height: ringSize.height)
                    .offset(y: -3)
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            if isCountingIn {
                Capsule()
                    .stroke(Color.gameGold, lineWidth: 5)
                    .frame(width: ringSize.width, height: ringSize.height)
                    .scaleEffect(pulse ? 1.08 : 0.96)
                    .opacity(pulse ? 0.2 : 1)
                    .offset(y: -3)
                    .onAppear {
                        withAnimation(.easeOut(duration: 0.5).repeatForever(autoreverses: false)) { pulse = true }
                    }
                    .onDisappear { pulse = false }
                    .allowsHitTesting(false)
            }
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isRecording)
        .accessibilityLabel(isRecording || isCountingIn ? Strings.Imitate.stop : Strings.Imitate.record)
    }

    private struct MicKeyStyle: ButtonStyle {
        let fill: Color
        let glow: CGFloat

        func makeBody(configuration: Configuration) -> some View {
            let pressed = configuration.isPressed
            let lip: CGFloat = 8
            configuration.label
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                            .fill(fill.opacity(0.35))
                            .scaleEffect(1 + glow * 0.18)
                            .blur(radius: 6)
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                            .fill(Color.gameNavy)
                            .offset(y: lip)
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                            .fill(fill)
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(.white.opacity(0.35))
                            .frame(height: 22)
                            .padding(.horizontal, 22)
                            .frame(maxHeight: .infinity, alignment: .top)
                            .padding(.top, 10)
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                            .strokeBorder(Color.gameNavy, lineWidth: 4)
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .strokeBorder(.white.opacity(0.9), lineWidth: 3)
                            .padding(5)
                    }
                }
                .offset(y: pressed ? lip * 0.75 : 0)
                .animation(.spring(response: 0.16, dampingFraction: 0.5), value: pressed)
                .animation(.easeOut(duration: 0.1), value: glow)
                .padding(.bottom, lip)
        }
    }
}

// MARK: - Deck

/// The pale control deck under a round's stage, with the navy edge the kit draws on its
/// panels.
struct GameDeck<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .background {
                Color.gameDeck
                    .overlay(alignment: .top) {
                        Rectangle().fill(Color.gameNavy).frame(height: 4)
                    }
                    .ignoresSafeArea(edges: .bottom)
            }
    }
}

// MARK: - Sound pictures

/// A sound's picture in the game's outlined style (`game-imitate-…`), or the shared
/// illustration when the game has none for it yet.
struct GameSoundArt: View {
    let sound: ImitationSound
    let size: CGFloat

    var body: some View {
        if UIImage(named: "game-\(sound.artworkName)") != nil {
            Image("game-\(sound.artworkName)")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        } else {
            ImitationSoundArtwork(sound: sound, size: size)
        }
    }
}

// MARK: - Stars

/// The kit's rating star, lit in foil-gold or empty.
struct GameStar: View {
    let isLit: Bool
    var size: CGFloat = 22
    /// Lit stars catch the light (`gameFoil`); off in long lists, where it would cost.
    var shines = true

    var body: some View {
        Image(isLit ? GameArt.Rating.filled : GameArt.Rating.empty)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .gameFoil(1, isActive: isLit && shines)
            .accessibilityHidden(true)
    }
}

extension Color {
    /// Whether the colour is light enough that navy text reads on it better than white.
    var gameIsLight: Bool {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b > 0.55
    }
}
