//
//  Typography.swift
//  ReverseSinging
//
//  Premium typography system
//

import SwiftUI

extension Font {
    // MARK: - Timer Display (Monospaced)
    // Note: Use .monospaced() view modifier for full monospace including punctuation
    static let rsTimerLarge = Font.system(size: 72, weight: .medium, design: .default)
    static let rsTimerMedium = Font.system(size: 56, weight: .medium, design: .default)
    static let rsTimerSmall = Font.system(size: 32, weight: .medium, design: .default)

    // MARK: - Display
    static let rsDisplayLarge = Font.system(size: 48, weight: .bold, design: .default)
    static let rsDisplayMedium = Font.system(size: 36, weight: .bold, design: .default)

    // MARK: - Headings
    static let rsHeadingLarge = Font.system(size: 32, weight: .semibold, design: .default)
    static let rsHeadingMedium = Font.system(size: 24, weight: .semibold, design: .default)
    static let rsHeadingSmall = Font.system(size: 20, weight: .semibold, design: .default)

    // MARK: - Body
    static let rsBodyLarge = Font.system(size: 18, weight: .regular, design: .default)
    static let rsBodyMedium = Font.system(size: 16, weight: .regular, design: .default)
    static let rsBodySmall = Font.system(size: 14, weight: .regular, design: .default)

    // MARK: - Button
    static let rsButtonLarge = Font.system(size: 18, weight: .semibold, design: .default)
    static let rsButtonMedium = Font.system(size: 16, weight: .semibold, design: .default)
    static let rsButtonSmall = Font.system(size: 14, weight: .medium, design: .default)

    // MARK: - Caption
    static let rsCaption = Font.system(size: 13, weight: .medium, design: .default)
    static let rsCaptionSmall = Font.system(size: 11, weight: .medium, design: .default)

    // MARK: - Label (for metadata)
    static let rsLabel = Font.system(size: 12, weight: .regular, design: .default)
    static let rsLabelSmall = Font.system(size: 10, weight: .regular, design: .default)
}

// MARK: - Text Modifiers
struct RSTextStyle: ViewModifier {
    enum Style {
        case timer, display, heading, body, button, caption, label
    }

    let style: Style

    func body(content: Content) -> some View {
        switch style {
        case .timer:
            content.font(.rsTimerMedium).foregroundColor(.rsText)
        case .display:
            content.font(.rsDisplayMedium).foregroundColor(.rsText)
        case .heading:
            content.font(.rsHeadingMedium).foregroundColor(.rsText)
        case .body:
            content.font(.rsBodyMedium).foregroundColor(.rsText)
        case .button:
            content.font(.rsButtonMedium)
        case .caption:
            content.font(.rsCaption).foregroundColor(.rsSecondaryText)
        case .label:
            content.font(.rsLabel).foregroundColor(.rsSecondaryText)
        }
    }
}

extension View {
    func textStyle(_ style: RSTextStyle.Style) -> some View {
        modifier(RSTextStyle(style: style))
    }
}
