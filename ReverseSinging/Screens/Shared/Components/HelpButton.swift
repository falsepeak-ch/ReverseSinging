//
//  HelpButton.swift
//  ReverseSinging
//
//  The question mark in a screen's header, opening Help on that screen's chapter
//

import SwiftUI

/// A header button that opens Help at the chapter about the screen it sits on.
///
/// It presents Help itself, so it works on any screen, a cover included, without the screen
/// having to own a sheet for it.
struct HelpButton: View {
    let topic: HelpTopic
    @State private var isPresented = false

    var body: some View {
        EditorToolbarButton(icon: "questionmark", label: Strings.Help.title) {
            isPresented = true
        }
        .sheet(isPresented: $isPresented) {
            HelpView(topic: topic)
                .presentationDragIndicator(.visible)
        }
    }
}
