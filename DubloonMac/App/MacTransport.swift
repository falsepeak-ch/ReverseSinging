//
//  MacTransport.swift
//  DubloonMac
//
//  What the Playback menu can do in whichever window is in front
//

import AppKit
import Combine
import SwiftUI

/// The transport of the workspace in a window, published to the menu bar.
///
/// Each workspace fills in the keys it has and leaves the rest nil, so the Playback menu greys
/// out what the game on screen cannot do, the way the menu of any editor follows its content.
struct MacTransport {
    var togglePlay: (@MainActor () -> Void)?
    var toggleRecord: (@MainActor () -> Void)?
    var listen: (@MainActor () -> Void)?
    var playTake: (@MainActor () -> Void)?
    var previous: (@MainActor () -> Void)?
    var next: (@MainActor () -> Void)?
    var export: (@MainActor () -> Void)?
    /// Moves the head five seconds, in whatever can be scrubbed.
    var skipBack: (@MainActor () -> Void)?
    var skipForward: (@MainActor () -> Void)?
    var goToStart: (@MainActor () -> Void)?
    /// The dub viewer's three modes, where there is a dub viewer.
    var setViewerMode: (@MainActor (DubViewerMode) -> Void)?
    var viewerMode: DubViewerMode?
    var zoomIn: (@MainActor () -> Void)?
    var zoomOut: (@MainActor () -> Void)?
    var toggleBooth: (@MainActor () -> Void)?
    /// The window's own inspector: each window shows or hides its own.
    var toggleInspector: (@MainActor () -> Void)?
    var isInspectorShown = false
    var isBoothOn = false
    var isRecording = false
}

extension MacTransport: Equatable {
    /// Two transports are the same when the same keys are live. The closures reach models by
    /// reference, so a transport with the same keys does the same thing.
    nonisolated static func == (lhs: MacTransport, rhs: MacTransport) -> Bool {
        lhs.availability == rhs.availability && lhs.isRecording == rhs.isRecording
            && lhs.viewerMode == rhs.viewerMode && lhs.isInspectorShown == rhs.isInspectorShown
    }

    private nonisolated var availability: [Bool] {
        [togglePlay, toggleRecord, listen, playTake, previous, next, export,
         skipBack, skipForward, goToStart, zoomIn, zoomOut, toggleBooth, toggleInspector].map { $0 != nil }
            + [setViewerMode != nil, isBoothOn]
    }
}

// MARK: - Hub

/// Every window's transport, and the one the menu bar acts on: the window in front.
///
/// Each editing window, the main one and every pack opened on its own, publishes its transport
/// here under its `NSWindow`. The menus follow `current`, which changes with the key window,
/// and the keyboard asks for the transport of the window a key was typed into. So Space in a
/// pack's own window plays that pack, never the one behind it.
@MainActor
final class MacTransportHub: ObservableObject {
    static let shared = MacTransportHub()

    /// The key window's transport, or the main window's while a panel such as Settings is key.
    @Published private(set) var current = MacTransport()

    private struct Entry {
        let token: UUID
        weak var window: NSWindow?
        var transport: MacTransport
    }

    private var entries: [Entry] = []

    private init() {
        for name in [NSWindow.didBecomeKeyNotification, NSWindow.didBecomeMainNotification, NSWindow.willCloseNotification] {
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
                Task { @MainActor in MacTransportHub.shared.refresh() }
            }
        }
    }

    /// Replaces whatever the publisher with this token said before. Tokens, not windows, key
    /// the entries: when the sidebar switches workspace the new one can appear before the old
    /// one has gone, and the old one's withdrawal must not take the new one's keys with it.
    func publish(_ transport: MacTransport, token: UUID, window: NSWindow) {
        entries.removeAll { $0.token == token || $0.window == nil }
        entries.append(Entry(token: token, window: window, transport: transport))
        refresh()
    }

    func withdraw(_ token: UUID) {
        entries.removeAll { $0.token == token }
        refresh()
    }

    /// The transport of the window, or of the window a sheet hangs from.
    func transport(for window: NSWindow?) -> MacTransport? {
        guard let window else { return nil }
        let host = window.sheetParent ?? window
        return entries.last { $0.window === host }?.transport
    }

    func refresh() {
        // The key window's, or the main window's while a panel such as Settings is key. In the
        // background there is neither, and the frontmost editing window stands in for them.
        let front = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.orderedWindows.first(where: MacWindowID.isEditing)
        // Assigned every time, not compared: two packs' windows can have the same keys live
        // and still be two different transports.
        current = transport(for: front) ?? transport(for: NSApp.mainWindow) ?? MacTransport()
    }
}

extension View {
    /// Hands this workspace's transport to its window, for the menu bar and the keyboard.
    ///
    /// Held by the hub under the window rather than passed as a focused value: a focused value
    /// goes away when the sidebar takes keyboard focus, and the transport keys went dead with it.
    func publishesTransport(_ transport: MacTransport) -> some View {
        modifier(TransportPublisher(transport: transport))
    }
}

private struct TransportPublisher: ViewModifier {
    let transport: MacTransport
    @State private var token = UUID()
    @State private var window: NSWindow?

    func body(content: Content) -> some View {
        content
            .background(WindowReader { found in
                if window !== found { window = found }
            })
            .onChange(of: transport, initial: true) { _, new in publish(new) }
            .onChange(of: window) { _, _ in publish(transport) }
            .onDisappear { MacTransportHub.shared.withdraw(token) }
    }

    private func publish(_ transport: MacTransport) {
        guard let window else { return }
        MacTransportHub.shared.publish(transport, token: token, window: window)
    }
}

/// Tells a view which window it has been put in.
struct WindowReader: NSViewRepresentable {
    let onWindow: @MainActor (NSWindow?) -> Void

    func makeNSView(context: Context) -> ReaderView {
        let view = ReaderView()
        view.onWindow = onWindow
        return view
    }

    func updateNSView(_ view: ReaderView, context: Context) {
        view.onWindow = onWindow
    }

    final class ReaderView: NSView {
        var onWindow: (@MainActor (NSWindow?) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            let window = window
            // After the update that moved it: state set during one is dropped.
            DispatchQueue.main.async { [weak self] in self?.onWindow?(window) }
        }
    }
}
