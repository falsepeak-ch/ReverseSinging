//
//  MacFileInbox.swift
//  DubloonMac
//
//  Packs handed to the app by Finder, the Dock icon or "Open With"
//

import SwiftUI
import Combine

/// Where the app delegate leaves a file the system asked the app to open, for the window to
/// pick up and import.
///
/// SwiftUI's `onOpenURL` does not reliably see a file opened on a single-`Window` app, so the
/// delegate takes `application(_:open:)` itself and posts the file here.
@MainActor
final class MacFileInbox: ObservableObject {
    static let shared = MacFileInbox()

    @Published var pending: URL?

    func deliver(_ urls: [URL]) {
        #if DEBUG
        FileHandle.standardError.write(Data("INBOX|\(urls.map(\.path))\n".utf8))
        #endif
        guard let url = urls.first(where: \.isFileURL) else { return }
        pending = url
    }
}
