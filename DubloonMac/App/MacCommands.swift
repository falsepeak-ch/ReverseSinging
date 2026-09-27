//
//  MacCommands.swift
//  DubloonMac
//
//  The menu bar: switching interface, and the ways to support the app.
//

import SwiftUI

/// Adds a View menu section for the two interfaces and a Help item that opens the App Store's
/// review form. Recording and playback live on the window's own buttons and keys.
struct MacCommands: Commands {
    @ObservedObject var app: AppViewModel
    @Environment(\.openURL) private var openURL

    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Picker(Strings.Settings.interface, selection: Binding(
                get: { app.uiMode },
                set: { app.setUIMode($0) }
            )) {
                ForEach(UIMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
        }

        CommandGroup(replacing: .help) {
            Button(Strings.ReviewBanner.rate) {
                openURL(ReviewBanner.writeReviewURL)
            }
        }

        // One window, reopened from the Window menu; no "New Window".
        CommandGroup(replacing: .newItem) {}
    }
}
