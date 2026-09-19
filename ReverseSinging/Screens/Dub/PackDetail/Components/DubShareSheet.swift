//
//  DubShareSheet.swift
//  ReverseSinging
//
//  The system share sheet for a finished dub
//

import SwiftUI

struct DubShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        // Only a dub that actually left the app counts. Opening the sheet and backing out
        // is not the finished thing we would be asking someone to rate.
        controller.completionWithItemsHandler = { _, completed, _, _ in
            guard completed else { return }
            Task { @MainActor in ReviewPrompt.shared.registerVideoShared() }
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
