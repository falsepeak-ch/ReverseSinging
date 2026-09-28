//
//  MacShotPoser.swift
//  DubloonMac
//
//  Puts the window into one App Store screenshot's state. Debug only.
//

#if DEBUG
import AppKit
import SwiftUI
import RevenueCat
import DubScoring

/// Started with `-macShot <name>` (plus `-screenshotMode YES`). Poses the window and logs
/// `E2E|SHOT|<name>|main` once it has settled, for the capture script to photograph, then
/// holds the pose for a few seconds and quits.
@MainActor
enum MacShotPoser {

    static func runIfRequested(workspace: MacWorkspaceViewModel) async {
        guard let name = UserDefaults.standard.string(forKey: "macShot") else { return }
        await sleep(2)
        NSApp.activate(ignoringOtherApps: true)
        DubScoringPreference.shared.isEnabled = true

        switch name {
        case "dub": await dubLine(workspace: workspace)
        case "scene": await dubScene(workspace: workspace)
        case "library": await library(workspace: workspace)
        case "paywall": await paywall(workspace: workspace)
        case "gate":
            workspace.select(.dubLibrary)
            await sleep(1)
            workspace.requestImport()
            await sleep(1.5)
        case "primer":
            if let editor = await openPack(workspace: workspace) {
                editor.record.isBoothPrimerPresented = true
                await sleep(1.5)
            }
        case "reverse": await reverse(workspace: workspace)
        case "imitate": await imitate(workspace: workspace)
        default: break
        }

        await sleep(1.5)
        // Key and in front, or the capture shows a dimmed, inactive window.
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first { MacWindowID.isKind(MacWindowID.main, $0) }?.makeKeyAndOrderFront(nil)
        await sleep(0.5)
        let windows = NSApp.windows.map { "\($0.identifier?.rawValue ?? "nil") visible=\($0.isVisible) key=\($0.isKeyWindow) \(Int($0.frame.width))x\(Int($0.frame.height))" }
        FileHandle.standardError.write(Data("SHOT|active=\(NSApp.isActive) windows=\(windows)\n".utf8))
        FileHandle.standardError.write(Data("E2E|SHOT|\(name)|main\n".utf8))
        await sleep(5)
        NSApp.terminate(nil)
    }

    // MARK: - Poses

    /// The recording bay on a dubbed line, the original rolling under the picture.
    private static func dubLine(workspace: MacWorkspaceViewModel) async {
        guard let editor = await openPack(workspace: workspace) else { return }
        let lines = editor.pack.lines
        if lines.indices.contains(ScreenshotMode.posedLineIndex) {
            editor.select(lines[ScreenshotMode.posedLineIndex])
        }
        await sleep(1)
        editor.record.toggleReferencePreview()
        await sleep(0.6)
    }

    /// The whole scene with the user's voices in it, held on a caption.
    private static func dubScene(workspace: MacWorkspaceViewModel) async {
        guard let editor = await openPack(workspace: workspace) else { return }
        editor.setMode(.myDub)
        _ = await waitUntil(8) { editor.playback?.player.isPlaying == true }
        await sleep(3.2)
        editor.playback?.togglePlayPause()
    }

    private static func library(workspace: MacWorkspaceViewModel) async {
        await seed(workspace: workspace)
        workspace.select(.dubLibrary)
        await sleep(1.5)
    }

    private static func reverse(workspace: MacWorkspaceViewModel) async {
        workspace.select(.reverse)
        await sleep(1.5)
        if let studio = MacE2EProbe.shared.reverse,
           let lane = studio.lanes.first(where: { $0.type == .reversed }) {
            studio.toggle(lane)
            await sleep(1.4)
        }
    }

    private static func imitate(workspace: MacWorkspaceViewModel) async {
        workspace.select(.imitate)
        _ = await waitUntil(3) { MacE2EProbe.shared.imitate?.challenge != nil }
        guard let studio = MacE2EProbe.shared.imitate else { return }
        let sound = UserDefaults.standard.string(forKey: "macShotSound") ?? "cat"
        let attempt = UserDefaults.standard.string(forKey: "macShotAttempt") ?? "horn"
        if let target = ImitationSoundLibrary.sound(id: sound) { studio.select(target) }
        await sleep(1)
        // A scored attempt, so the comparison, the verdict and the radar are all on show.
        guard let challenge = studio.challenge,
              let take = ImitationSoundLibrary.sound(id: attempt)?.url else { return }
        await challenge.debugJudge(takeFrom: take)
        FileHandle.standardError.write(Data("SHOT|score=\(challenge.score?.overall ?? -1)\n".utf8))
        await sleep(2.5)
    }

    /// Reports what RevenueCat and the store answer, then opens the paywall.
    private static func paywall(workspace: MacWorkspaceViewModel) async {
        func log(_ line: String) { FileHandle.standardError.write(Data("RC|\(line)\n".utf8)) }
        _ = await waitUntil(10) { Purchases.isConfigured }
        log("configured=\(Purchases.isConfigured) key=\(PurchaseConfiguration.isUsingTestStore ? "test" : "appstore")")
        guard Purchases.isConfigured else { return }
        do {
            let info = try await Purchases.shared.customerInfo()
            log("customer=\(info.originalAppUserId) entitlements=\(info.entitlements.all.keys.sorted()) active=\(info.entitlements.active.keys.sorted()) env=\(info.entitlements.verification)")
            let offerings = try await Purchases.shared.offerings()
            log("offerings=\(offerings.all.keys.sorted()) current=\(offerings.current?.identifier ?? "nil")")
            for (id, offering) in offerings.all.sorted(by: { $0.key < $1.key }) {
                for package in offering.availablePackages {
                    let product = package.storeProduct
                    log("offering=\(id) package=\(package.identifier) product=\(product.productIdentifier) price=\(product.localizedPriceString) type=\(product.productType) intro=\(product.introductoryDiscount.map { "\($0.subscriptionPeriod.value) \($0.subscriptionPeriod.unit) \($0.paymentMode)" } ?? "none")")
                }
            }
            let direct = await Purchases.shared.products([
                "com.falsepeak.reverse_singing_ios.lifetime",
                "com.falsepeak.reverse_singing_ios.monthly",
                "com.falsepeak.reverse_singing_ios.yearly"
            ])
            log("direct products=\(direct.map { "\($0.productIdentifier) \($0.localizedPriceString)" }.sorted())")
        } catch {
            log("error=\(error)")
        }
        workspace.home.showPaywall(from: .trialBadge)
        await sleep(6)
    }

    // MARK: - Helpers

    private static func seed(workspace: MacWorkspaceViewModel) async {
        _ = await waitUntil(6) { !workspace.packs.isEmpty }
        guard let pack = workspace.packs.first(where: { $0.title == "Stuck Up" }) ?? workspace.packs.first else { return }
        ScreenshotMode.seedTakes(for: pack)
        await workspace.dubLibrary.library.reloadNow()
    }

    private static func openPack(workspace: MacWorkspaceViewModel) async -> DubEditorViewModel? {
        await seed(workspace: workspace)
        guard let pack = workspace.packs.first(where: { $0.title == "Stuck Up" }) ?? workspace.packs.first else { return nil }
        workspace.select(.pack(pack.id))
        _ = await waitUntil(5) { MacE2EProbe.shared.dubEditor != nil }
        await sleep(1)
        return MacE2EProbe.shared.dubEditor
    }

    private static func sleep(_ seconds: TimeInterval) async {
        try? await Task.sleep(for: .seconds(seconds))
    }

    private static func waitUntil(_ timeout: TimeInterval, _ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            await sleep(0.05)
        }
        return condition()
    }
}
#endif
