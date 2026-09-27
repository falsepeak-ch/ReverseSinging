//
//  PlatformSupport.swift
//  ReverseSinging
//
//  The few things iOS and the Mac spell differently, spelled once.
//

import Foundation
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Whether the app is the one in front, which is when it may open the microphone.
enum AppActivity {
    static var isActive: Bool {
        #if os(iOS)
        UIApplication.shared.applicationState == .active
        #else
        NSApp.isActive
        #endif
    }
}

/// Keeps long work alive when the user looks away: background time on iOS, where a suspended
/// app loses its encoder mid-render, and an activity on the Mac, where App Nap would slow it
/// to a crawl behind another window.
///
/// Call `end()` when the work is done, usually from a `defer`.
struct LongRunningWork {
    #if os(iOS)
    private let task: UIBackgroundTaskIdentifier
    #else
    private let activity: NSObjectProtocol
    #endif

    init(name: String) {
        #if os(iOS)
        task = UIApplication.shared.beginBackgroundTask(withName: name)
        #else
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled], reason: name
        )
        #endif
    }

    func end() {
        #if os(iOS)
        if task != .invalid { UIApplication.shared.endBackgroundTask(task) }
        #else
        ProcessInfo.processInfo.endActivity(activity)
        #endif
    }
}

/// Opens a web page or a system URL in whatever handles it.
@MainActor
func openExternally(_ url: URL) {
    #if os(iOS)
    UIApplication.shared.open(url)
    #else
    NSWorkspace.shared.open(url)
    #endif
}

#if os(iOS)
typealias PlatformImage = UIImage
#else
typealias PlatformImage = NSImage
#endif

extension PlatformImage {
    /// `UIImage(cgImage:)`, spelled so the Mac's `NSImage` answers to it too.
    static func make(cgImage: CGImage) -> PlatformImage {
        #if os(iOS)
        UIImage(cgImage: cgImage)
        #else
        NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        #endif
    }
}

import SwiftUI

extension Image {
    init(platformImage: PlatformImage) {
        #if os(iOS)
        self.init(uiImage: platformImage)
        #else
        self.init(nsImage: platformImage)
        #endif
    }
}

// MARK: - Presentation

/// How big a cover is on the Mac, where there is no screen to cover: a sheet that fills most
/// of the window. Kept under the window's own minimum (see `DubloonMacApp`) so it never
/// spills past the window it hangs from.
private let macCoverMinSize = CGSize(width: 820, height: 660)

extension View {

    /// The screens draw their own header, so the system bar goes: the navigation bar on iOS.
    /// On the Mac only the back button a pushed view would add to the title bar; hiding the
    /// whole window toolbar takes the close and minimise buttons with it.
    func hidesNavigationBar() -> some View {
        #if os(iOS)
        toolbar(.hidden, for: .navigationBar)
        #else
        navigationBarBackButtonHidden(true)
        #endif
    }

    /// iOS only; a Mac window has no status bar.
    func hidesStatusBar() -> some View {
        #if os(iOS)
        statusBarHidden()
        #else
        self
        #endif
    }

    /// A large title on iOS. The Mac has one title size.
    func largeNavigationTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.large)
        #else
        self
        #endif
    }

    /// `fullScreenCover` on iOS; a large sheet on the Mac.
    func coversScreen<Content: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        #if os(iOS)
        fullScreenCover(isPresented: isPresented, onDismiss: onDismiss, content: content)
        #else
        sheet(isPresented: isPresented, onDismiss: onDismiss) {
            content().frame(minWidth: macCoverMinSize.width, minHeight: macCoverMinSize.height)
        }
        #endif
    }

    /// `fullScreenCover(item:)` on iOS; a large sheet on the Mac.
    func coversScreen<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        #if os(iOS)
        fullScreenCover(item: item, onDismiss: onDismiss, content: content)
        #else
        sheet(item: item, onDismiss: onDismiss) { value in
            content(value).frame(minWidth: macCoverMinSize.width, minHeight: macCoverMinSize.height)
        }
        #endif
    }
}

extension ToolbarItemPlacement {
    /// Top right on the iPhone; on the Mac, where a sheet has no navigation bar, the place a
    /// sheet's close button goes.
    static var rsTrailing: ToolbarItemPlacement {
        #if os(iOS)
        .topBarTrailing
        #else
        .cancellationAction
        #endif
    }
}
