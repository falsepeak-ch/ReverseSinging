//
//  Typography.swift
//  ReverseSinging
//
//  Design system typography
//

import SwiftUI

extension Font {
    // MARK: - Display
    static let rsDisplayLarge = Font.system(size: 48, weight: .bold, design: .rounded)
    static let rsDisplayMedium = Font.system(size: 36, weight: .bold, design: .rounded)

    // MARK: - Headings
    static let rsHeadingLarge = Font.system(size: 32, weight: .semibold, design: .rounded)
    static let rsHeadingMedium = Font.system(size: 24, weight: .semibold, design: .rounded)
    static let rsHeadingSmall = Font.system(size: 20, weight: .semibold, design: .rounded)

    // MARK: - Body
    static let rsBodyLarge = Font.system(size: 18, weight: .regular, design: .rounded)
    static let rsBodyMedium = Font.system(size: 16, weight: .regular, design: .rounded)
    static let rsBodySmall = Font.system(size: 14, weight: .regular, design: .rounded)

    // MARK: - Button
    static let rsButtonLarge = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let rsButtonMedium = Font.system(size: 18, weight: .semibold, design: .rounded)

    // MARK: - Caption
    static let rsCaption = Font.system(size: 12, weight: .medium, design: .rounded)
    static let rsCaptionSmall = Font.system(size: 10, weight: .medium, design: .rounded)
}

// MARK: - Text Modifiers
struct RSTextStyle: ViewModifier {
    enum Style {
        case display, heading, body, button, caption
    }

    let style: Style

    func body(content: Content) -> some View {
        switch style {
        case .display:
            content.font(.rsDisplayMedium).foregroundColor(.rsText)
        case .heading:
            content.font(.rsHeadingMedium).foregroundColor(.rsText)
        case .body:
            content.font(.rsBodyMedium).foregroundColor(.rsText)
        case .button:
            content.font(.rsButtonMedium).foregroundColor(.rsButtonText)
        case .caption:
            content.font(.rsCaption).foregroundColor(.rsSecondaryText)
        }
    }
}

extension View {
    func textStyle(_ style: RSTextStyle.Style) -> some View {
        modifier(RSTextStyle(style: style))
    }
}
