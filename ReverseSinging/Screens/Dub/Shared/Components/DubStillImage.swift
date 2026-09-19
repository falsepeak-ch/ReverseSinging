//
//  DubStillImage.swift
//  ReverseSinging
//
//  A pack still, decoded off the main thread
//

import SwiftUI

/// Loads a pack still off the main thread and keeps it decoded for the view's lifetime.
struct DubStillImage: View {
    let url: URL
    var contentMode: ContentMode = .fill

    @State private var image: UIImage?

    var body: some View {
        // The image goes in an overlay rather than a ZStack sibling: an aspect-fill image is
        // wider than its frame, and as a ZStack child it would size the stack, and anything
        // laid out over it, past the screen edge.
        Color.black
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                }
            }
            .clipped()
            .task(id: url) {
                guard image == nil else { return }
                let path = url.path
                image = await Task.detached(priority: .userInitiated) {
                    UIImage(contentsOfFile: path)
                }.value
            }
    }
}
