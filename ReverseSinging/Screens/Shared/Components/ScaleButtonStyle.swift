//
//  ScaleButtonStyle.swift
//  ReverseSinging
//
//  A button that gives slightly under the finger
//

import SwiftUI

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.rsQuick, value: configuration.isPressed)
    }
}
