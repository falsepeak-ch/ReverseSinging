//
//  MacTransport.swift
//  DubloonMac
//
//  What the Playback menu can do in whichever workspace is on screen
//

import SwiftUI

/// The transport of the workspace in the window, published to the menu bar.
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
    var isBoothOn = false
    var isRecording = false
}

extension MacTransport: Equatable {
    /// Two transports are the same when the same keys are live. The closures reach models by
    /// reference, so a transport with the same keys does the same thing.
    nonisolated static func == (lhs: MacTransport, rhs: MacTransport) -> Bool {
        lhs.availability == rhs.availability && lhs.isRecording == rhs.isRecording
            && lhs.viewerMode == rhs.viewerMode
    }

    private nonisolated var availability: [Bool] {
        [togglePlay, toggleRecord, listen, playTake, previous, next, export,
         skipBack, skipForward, goToStart, zoomIn, zoomOut, toggleBooth].map { $0 != nil }
            + [setViewerMode != nil, isBoothOn]
    }
}

extension View {
    /// Hands this workspace's transport to the window, for the menu bar and the keyboard.
    ///
    /// Held by the window's model rather than passed as a focused value: a focused value goes
    /// away when the sidebar takes keyboard focus, and the transport keys went dead with it.
    func publishesTransport(_ transport: MacTransport, to workspace: MacWorkspaceViewModel) -> some View {
        onChange(of: transport, initial: true) { _, new in
            workspace.transport = new
        }
    }
}
