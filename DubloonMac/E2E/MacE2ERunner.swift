//
//  MacE2ERunner.swift
//  DubloonMac
//
//  An end-to-end walk through the Mac app, driven from inside it. Debug only.
//

#if DEBUG
import AppKit
import AVFoundation
import DubCompositing
import SwiftUI

/// Walks the whole app the way a person would: first run, every workspace, the menu bar and
/// the keyboard, playback, export, and the window at its smallest and largest.
///
/// Started with `-macE2E YES` (plus `-screenshotMode YES` so no paywall or Firebase gets in
/// the way). Keys are real `NSEvent`s sent through `NSApp`, so they travel the same path as a
/// keystroke: key equivalents, the menu bar, the focused transport. Each step logs
/// `E2E|PASS|…` or `E2E|FAIL|…` to stderr, and `E2E|SHOT|name` where a screenshot should be
/// taken from outside; the run holds still for a moment after each one.
@MainActor
enum MacE2ERunner {

    private static var failures = 0
    private static var passes = 0

    static func runIfRequested(app: AppViewModel, workspace: MacWorkspaceViewModel) async {
        guard MacE2EProbe.isActive else { return }
        await sleep(2.5)
        NSApp.activate(ignoringOtherApps: true)
        mainWindow?.makeKeyAndOrderFront(nil)
        log("E2E|START")

        await welcome(app: app, workspace: workspace)
        await reverse(workspace: workspace)
        await sessions(workspace: workspace)
        await dub(workspace: workspace)
        await homeVideo(workspace: workspace)
        await imitate(workspace: workspace)
        await menus(workspace: workspace)
        await helpAndGuide(workspace: workspace)
        await native(workspace: workspace)
        await packWindows(workspace: workspace)
        await settingsWindow()
        await windowSizes(workspace: workspace)

        log("E2E|DONE|passed=\(passes)|failed=\(failures)")
        await sleep(1)
        NSApp.terminate(nil)
    }

    // MARK: - First Run

    private static func welcome(app: AppViewModel, workspace: MacWorkspaceViewModel) async {
        section("welcome")
        _ = await waitUntil(3) { window(MacWindowID.welcome) != nil }
        let welcomeWindow = window(MacWindowID.welcome)
        check("the welcome window is up on first run", welcomeWindow != nil)
        check("the welcome is its own window, not a sheet", mainWindow?.attachedSheet == nil)
        check("onboarding not yet complete", !app.hasCompletedOnboarding)
        welcomeWindow?.makeKeyAndOrderFront(nil)
        pressTarget = welcomeWindow
        await shot("01-welcome", window: "welcome")

        press(.return)
        let finished = await waitUntil(3) { app.hasCompletedOnboarding && window(MacWindowID.welcome) == nil }
        check("Return (Continue) finishes onboarding and closes the welcome window", finished)
        pressTarget = nil
        mainWindow?.makeKeyAndOrderFront(nil)
        check("a workspace is selected after onboarding", workspace.selection != nil)
    }

    // MARK: - Reverse Singing

    private static func reverse(workspace: MacWorkspaceViewModel) async {
        section("reverse")
        press(.key("1"), command: true)
        let shown = await waitUntil(3) { workspace.selection == .reverse && MacE2EProbe.shared.reverse != nil }
        check("⌘1 opens Reverse Singing", shown)
        guard let studio = MacE2EProbe.shared.reverse else { return }

        let lanesFull = studio.lanes.allSatisfy { $0.recording != nil }
        check("seeded session fills all four tracks", lanesFull, "\(studio.lanes.map { $0.recording != nil })")
        let waveforms = await waitUntil(5) { studio.lanes.allSatisfy { lane in lane.recording.map { !(studio.waveforms[$0.id] ?? []).isEmpty } ?? false } }
        check("every track draws a waveform", waveforms)
        check("record key offers another take", studio.recordStep == .anotherTake, "\(studio.recordStep)")
        check("a score is on the dashboard", studio.score != nil)
        await shot("03-reverse")

        focus(.sidebar)
        press(.space)
        let playing = await waitUntil(2) { studio.playingRecordingID != nil && studio.lamp == .playing }
        check("Space plays a track even with the sidebar focused", playing)
        check("Space leaves the sidebar selection alone", workspace.selection == .reverse)
        await sleep(1.0)
        let lane = studio.lanes.first { studio.isPlaying($0) }
        check("playhead advances on the playing track", (lane.flatMap { studio.progress(of: $0) } ?? 0) > 0.05)
        await shot("04-reverse-playing")
        press(.space)
        let stopped = await waitUntil(2) { studio.playingRecordingID == nil }
        check("Space again stops it", stopped)

        for lane in studio.lanes {
            studio.toggle(lane)
            let started = await waitUntil(2) { studio.isPlaying(lane) }
            check("track \(lane.type.rawValue) plays from its own key", started)
            studio.toggle(lane)
            _ = await waitUntil(2) { !studio.isPlaying(lane) }
        }

        studio.game.setPlaybackSpeed(1.5)
        check("speed knob reaches the player", abs(studio.game.appState.playbackSpeed - 1.5) < 0.01)
        studio.game.setPlaybackSpeed(1.0)
        studio.game.setPitchShift(300)
        check("pitch knob reaches the player", abs(studio.game.appState.pitchShift - 300) < 1)
        studio.game.setPitchShift(0)
        let loopBefore = studio.game.appState.isLooping
        studio.game.toggleLooping()
        check("loop switch toggles", studio.game.appState.isLooping != loopBefore)
        studio.game.toggleLooping()
    }

    // MARK: - Sessions

    private static func sessions(workspace: MacWorkspaceViewModel) async {
        section("sessions")
        let before = workspace.sessions.count
        press(.key("n"), command: true)
        let saved = await waitUntil(2) { workspace.sessions.count == before + 1 }
        check("⌘N files the session in the sidebar", saved, "\(before) → \(workspace.sessions.count)")
        if let studio = MacE2EProbe.shared.reverse {
            check("the new session starts with empty tracks", studio.lanes.allSatisfy { $0.recording == nil })
            check("record key is armed for the original", studio.recordStep == .recordOriginal, "\(studio.recordStep)")
        }
        await shot("05-reverse-new-session")

        guard let archived = workspace.sessions.first else { return }
        workspace.select(.session(archived.id))
        let opened = await waitUntil(2) { MacE2EProbe.shared.reverse?.isArchived == true }
        check("an archived session opens read-only", opened)
        if let studio = MacE2EProbe.shared.reverse {
            check("archived session has its recordings", studio.lanes.filter { $0.recording != nil }.count == 4)
            check("record is unavailable in the archive", studio.recordStep == .unavailable)
        }
        await shot("06-session-archive")

        workspace.deleteSession(archived)
        let deleted = await waitUntil(2) { workspace.sessions.count == before && workspace.selection == .reverse }
        check("deleting an archived session removes it and returns to the studio", deleted)
    }

    // MARK: - Dub

    /// The pack the run dubs, and so the one with takes in it: what Export Video needs.
    /// Stuck Up by name rather than whichever is first: the shelf's order changes as packs
    /// are added, and the Finder test re-imports Camp Rules, which moves it to the top.
    private static func seededPack(in workspace: MacWorkspaceViewModel) -> DubPack? {
        workspace.packs.first(where: { $0.title == "Stuck Up" }) ?? workspace.packs.first
    }

    private static func dub(workspace: MacWorkspaceViewModel) async {
        section("dub")
        guard let pack = seededPack(in: workspace) else {
            check("a dub pack is installed", false)
            return
        }
        // A known start: every run records a take, so earlier runs' takes are cleared and the
        // standard seven seeded again.
        let takes = AudioFileManager.shared.dubTakesDirectory(packID: pack.id)
        let existing = (try? FileManager.default.contentsOfDirectory(at: takes, includingPropertiesForKeys: nil)) ?? []
        var removed = 0
        for file in existing {
            do { try FileManager.default.removeItem(at: file); removed += 1 } catch { log("E2E|INFO|could not remove \(file.lastPathComponent): \(error)") }
        }
        ScreenshotMode.seedTakes(for: pack)
        let after = (try? FileManager.default.contentsOfDirectory(at: takes, includingPropertiesForKeys: nil))?.count ?? -1
        log("E2E|INFO|takes reset in \(pack.title): \(existing.count) found, \(removed) removed, \(after) after seeding")
        await workspace.dubLibrary.library.reloadNow()

        press(.key("2"), command: true)
        let browsing = await waitUntil(3) { workspace.selection == .dubLibrary }
        check("⌘2 opens the Movie Scene Dub library", browsing)
        await shot("07a-dub-library")

        let started = Date()
        workspace.select(.pack(pack.id))
        let opened = await waitUntil(5) { MacE2EProbe.shared.dubEditor != nil && workspace.selection == .pack(pack.id) }
        check("a pack opens in the editor", opened)
        guard let editor = MacE2EProbe.shared.dubEditor else { return }
        log("E2E|INFO|editor opened in \(String(format: "%.2f", Date().timeIntervalSince(started)))s")
        let session = editor.session

        check("the lines browser has every line", !editor.pack.lines.isEmpty)
        check("seeded takes are counted", session.recordedCount >= min(7, editor.pack.lines.count), "\(session.recordedCount)")
        let firstOpen = editor.pack.lines.firstIndex { !session.isRecorded($0) }
        check("editor opens on the first undubbed line", session.currentLineIndex == firstOpen,
              "at \(session.currentLineIndex), first undubbed \(firstOpen.map(String.init) ?? "none")")
        let waves = await waitUntil(3) { !editor.record.referenceSamples.isEmpty }
        check("the line's reference waveform loads", waves)
        await shot("07-dub-line")

        focus(.linesTable)
        let index = session.currentLineIndex
        press(.down)
        let movedDown = await waitUntil(1) { session.currentLineIndex == index + 1 }
        check("↓ goes to the next line", movedDown)
        press(.up)
        let movedUp = await waitUntil(1) { session.currentLineIndex == index }
        check("↑ goes back", movedUp)

        focus(.linesTable)
        let lineBefore = session.currentLineIndex
        press(.key("l"))
        let listening = await waitUntil(1.5) { session.isPreviewingReference }
        check("L plays the original line with the lines table focused", listening)
        check("L does not type-select a line", session.currentLineIndex == lineBefore)
        await sleep(0.5)
        check("the picture rolls with the original", (editor.record.scenePicture.player?.rate ?? 0) > 0 || editor.record.scenePicture.player == nil)
        await shot("08-dub-listening")
        _ = await waitUntil((session.currentLine?.duration ?? 3) + 2) { !session.isPreviewingReference }
        check("the preview ends on its own", !session.isPreviewingReference)

        focus(.sidebar)
        press(.key("l"))
        let listeningFromSidebar = await waitUntil(1.5) { session.isPreviewingReference }
        check("L plays the line with the sidebar focused", listeningFromSidebar)
        check("L does not jump the sidebar to another game", workspace.selection == .pack(pack.id))
        session.stopPlayback()
        focus(.linesTable)

        if let recorded = editor.pack.lines.first(where: session.isRecorded) {
            editor.select(recorded)
            _ = await waitUntil(1) { session.currentLine?.id == recorded.id }
            press(.key("p"))
            let takePlays = await waitUntil(1.5) { session.isPreviewingReference }
            check("P plays the take on a dubbed line", takePlays)
            session.stopPlayback()
        }

        for mode in [DubViewerMode.original, .myDub] {
            editor.setMode(mode)
            let rolling = await waitUntil(8) { editor.playback?.player.isPlaying == true }
            check("\(mode.title) starts playing the scene", rolling)
            let t0 = editor.session.scenePlayer.currentTime
            await sleep(1.2)
            let t1 = editor.session.scenePlayer.currentTime
            check("\(mode.title) clock advances", t1 - t0 > 0.8, String(format: "%.2f → %.2f", t0, t1))
            check("\(mode.title) picture follows", editor.playback?.scenePicture.player == nil || (editor.playback?.scenePicture.player?.rate ?? 0) > 0)
            await shot(mode == .original ? "09-dub-original" : "10-dub-mydub")
        }

        press(.space)
        let paused = await waitUntil(1) { editor.playback?.player.isPlaying == false }
        check("Space pauses the scene", paused)
        editor.scrub(to: 10)
        editor.endScrub()
        let scrubbed = await waitUntil(1) { abs(editor.session.scenePlayer.currentTime - 10) < 0.3 }
        check("scrubbing moves the head", scrubbed, String(format: "%.2f", editor.session.scenePlayer.currentTime))
        let before = editor.session.scenePlayer.currentTime
        press(.down)
        let jumped = await waitUntil(1) { editor.session.scenePlayer.currentTime > before + 0.05 }
        check("↓ in the scene jumps to the next line", jumped)

        editor.setMode(.line)
        check("back to Line tears the program monitor down", editor.playback == nil)

        let zoom = editor.zoom
        press(.key("="), command: true)
        let zoomedIn = await waitUntil(1) { editor.zoom > zoom }
        check("⌘= zooms the timeline in", zoomedIn)
        press(.key("-"), command: true)
        let zoomedOut = await waitUntil(1) { editor.zoom < zoom + 0.1 }
        check("⌘- zooms back out", zoomedOut)

        press(.key("i"), command: true, option: true)
        let hidden = await waitUntil(1) { !workspace.showsInspector }
        check("⌥⌘I hides the inspector", hidden)
        await shot("11-dub-no-inspector")
        press(.key("i"), command: true, option: true)
        _ = await waitUntil(1) { workspace.showsInspector }

        await record(editor: editor)
        await export(editor: editor)
    }

    private static func record(editor: DubEditorViewModel) async {
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else {
            log("E2E|SKIP|recording a take — microphone not granted to this build")
            return
        }
        let session = editor.session
        guard let line = editor.pack.lines.first(where: { !session.isRecorded($0) }) else { return }
        editor.select(line)
        press(.key("r"))
        let counting = await waitUntil(1) { editor.record.countdown != nil }
        check("R starts the count-in", counting)
        let rolling = await waitUntil(5) { editor.record.isRecording }
        check("the mic opens after the count", rolling)
        await shot("12-dub-recording")
        let landed = await waitUntil(line.duration + 4) { session.isRecorded(line) }
        check("the take is filed when the line ends", landed)
    }

    private static func export(editor: DubEditorViewModel) async {
        let detail = editor.detail
        press(.key("e"), command: true)
        let options = await waitUntil(2) { detail.showExportOptions }
        check("⌘E opens the export options", options)
        await shot("13-dub-export-options")

        detail.configureExport(cut: .fullScene, frame: .off, includesBooth: false)
        let notice = await waitUntil(2) { detail.showShareNotice }
        check("the attribution notice follows", notice)
        await shot("14-dub-share-notice")

        detail.showShareNotice = false
        let started = Date()
        detail.confirmExport()
        let exporting = await waitUntil(2) { detail.isExporting }
        check("the render starts", exporting)
        await sleep(0.8)
        await shot("15-dub-exporting")
        let done = await waitUntil(180) { detail.exportedURL != nil || (!detail.isExporting && editor.session.errorMessage != nil) }
        check("the render finishes", done && detail.exportedURL != nil, editor.session.errorMessage ?? "")
        log("E2E|INFO|export took \(String(format: "%.1f", Date().timeIntervalSince(started)))s")
        if let url = detail.exportedURL {
            let seconds = (try? await AVURLAsset(url: url).load(.duration).seconds) ?? 0
            let expected = editor.pack.duration
            check("the file runs the length of the scene", abs(seconds - expected) < 1.5, String(format: "%.2fs vs %.2fs", seconds, expected))
            let tracks = (try? await AVURLAsset(url: url).loadTracks(withMediaType: .video).count) ?? 0
            check("the file has a picture", tracks > 0)
            await sleep(0.8)
            await shot("16-dub-save-panel")
            detail.exportedURL = nil
        }
    }

    // MARK: - Home Video

    private static func homeVideo(workspace: MacWorkspaceViewModel) async {
        section("homeVideo")
        press(.key("3"), command: true)
        let opened = await waitUntil(3) { workspace.selection == .homeVideo && MacE2EProbe.shared.homeVideo != nil }
        check("⌘3 opens Home Video Dub", opened)
        guard let studio = MacE2EProbe.shared.homeVideo else { return }
        let dub = studio.dub
        check("the studio opens empty, on the picker", dub.phase == .empty)
        await shot("16a-home-video-empty")

        // A scene from a starter pack stands in for a video from Finder.
        guard let clip = seededPack(in: workspace)?.videoURL else {
            check("a video to load", false)
            return
        }
        check("a text file dropped on the viewer is turned away", !studio.handleDrop([URL(fileURLWithPath: "/tmp/notes.txt")]))
        check("a video dropped on the viewer is taken", studio.handleDrop([clip]))
        let loaded = await waitUntil(15) { dub.phase == .ready }
        check("the video loads", loaded, dub.errorMessage ?? "")
        _ = await waitUntil(5) { !dub.originalSamples.isEmpty || dub.source?.hasSound == false }
        check("the clip's sound is drawn", !dub.originalSamples.isEmpty || dub.source?.hasSound == false)
        await shot("16b-home-video-loaded")

        press(.space)
        let playing = await waitUntil(1.5) { dub.isPlaying }
        check("Space plays the clip", playing)
        press(.space)
        _ = await waitUntil(1.5) { !dub.isPlaying }

        press(.key("r"))
        let recording = await waitUntil(6) { dub.phase == .recording }
        check("R records a voice over the clip", recording)
        await sleep(1.5)
        await shot("16c-home-video-recording")
        if dub.phase == .recording { press(.key("r")) }
        let mixed = await waitUntil(60) { dub.phase == .review }
        check("the voice is mixed onto the video", mixed, dub.errorMessage ?? "")
        check("the take is drawn over the clip's sound", !dub.takeSamples.isEmpty)
        await sleep(1.0)
        await shot("16d-home-video-review")

        press(.key("e"), command: true)
        let shared = await waitUntil(2) { dub.sharedURL != nil }
        check("⌘E hands over the finished video", shared)
        if let url = dub.sharedURL {
            let tracks = (try? await AVURLAsset(url: url).loadTracks(withMediaType: .video).count) ?? 0
            check("the finished file has a picture", tracks > 0)
            await sleep(0.8)
            await shot("16e-home-video-share")
            dub.sharedURL = nil
        }
    }

    // MARK: - Imitate

    private static func imitate(workspace: MacWorkspaceViewModel) async {
        section("imitate")
        press(.key("4"), command: true)
        let opened = await waitUntil(3) { MacE2EProbe.shared.imitate?.challenge != nil }
        check("⌘4 opens Sound Imitation on a sound", opened)
        guard let studio = MacE2EProbe.shared.imitate, let challenge = studio.challenge else { return }
        let bars = await waitUntil(3) { !challenge.referenceBars.isEmpty }
        check("the sound's waveform loads", bars)
        check("the sound file is in the Mac bundle", challenge.sound.url != nil)
        await shot("17-imitate")

        press(.key("l"))
        let playing = await waitUntil(1.5) { challenge.playingClip == .reference }
        check("L plays the sound", playing)
        await shot("18-imitate-listening")

        press(.key("l"))
        _ = await waitUntil(1.5) { challenge.playingClip == nil }

        // An attempt, drawn live and then against the sound.
        press(.key("r"))
        let recording = await waitUntil(6) { challenge.phase == .recording }
        check("R starts an imitation", recording)
        await sleep(1.0)
        await shot("18a-imitate-recording")
        if challenge.phase == .recording { press(.key("r")) }
        let judged = await waitUntil(12) { challenge.phase == .result }
        check("the attempt is judged", judged)
        check("the attempt's audio is there to draw", challenge.takeFileURL != nil)
        await sleep(1.5)
        await shot("18b-imitate-result")

        // ↓ walks the browser.
        let order = studio.visibleSounds
        let expected = order.firstIndex(of: challenge.sound).map { order[min($0 + 1, order.count - 1)] }
        press(.down)
        let walked = await waitUntil(1.5) { studio.challenge?.sound == expected }
        check("↓ moves to the next sound", walked, studio.challenge?.sound.id ?? "none")
        check("the previous sound stopped", challenge.playingClip == nil)

        // The filter narrows the browser to one category.
        let saved = studio.category
        studio.category = .vehicles
        check("the filter lists one category", studio.visibleSounds.allSatisfy { $0.category == .vehicles } && !studio.visibleSounds.isEmpty)
        studio.category = saved
    }

    // MARK: - Help

    private static func helpAndGuide(workspace: MacWorkspaceViewModel) async {
        section("help")
        workspace.select(.reverse)
        await sleep(0.8)
        press(.key("?"), command: true, shift: true)
        let opened = await waitUntil(3) { window(MacWindowID.help) != nil }
        check("⌘? opens Help in a window of its own", opened)
        let help = MacHelpViewModel.shared
        check("Help opens on the chapter for the workspace in front", help.topic == .reverse, "\(String(describing: help.topic))")
        check("the answers are worded for the Mac", help.articles.first?.answer.contains("Click") == true)
        check("Help lists every chapter's questions", HelpTopic.allCases.allSatisfy { !$0.articles.isEmpty && !$0.articles[0].question.hasPrefix("help.") })
        await shot("24-help", window: "help")
        help.help.query = "microphone"
        await sleep(0.4)
        check("Help search finds answers across chapters", Set(help.articles.map(\.topic)).count > 1)
        await shot("24b-help-search", window: "help")
        help.help.query = ""
        window(MacWindowID.help)?.close()
        mainWindow?.makeKeyAndOrderFront(nil)

        section("packGuide")
        workspace.select(.dubLibrary)
        await sleep(0.8)
        workspace.showPackGuide()
        let shown = await waitUntil(2) { mainWindow?.attachedSheet != nil }
        check("the pack guide opens over the library", shown && workspace.dubLibrary.showPackGuide)
        await shot("25-pack-guide")
        workspace.dubLibrary.showPackGuide = false
        _ = await waitUntil(2) { mainWindow?.attachedSheet == nil }
    }

    // MARK: - Menus

    private static func menus(workspace: MacWorkspaceViewModel) async {
        section("menus")
        let expectations: [(MacDestination?, [String: Bool])] = [
            (.reverse, [MacStrings.Menu.playPause: true, MacStrings.Menu.nextLine: false, MacStrings.Menu.export: false]),
            (seededPack(in: workspace).map { .pack($0.id) }, [MacStrings.Menu.playPause: true, MacStrings.Menu.nextLine: true, MacStrings.Menu.listen: true, MacStrings.Menu.export: true]),
            (.imitate, [MacStrings.Menu.playPause: true, MacStrings.Menu.nextLine: true, MacStrings.Menu.listen: true])
        ]
        for (destination, expected) in expectations {
            guard let destination else { continue }
            workspace.select(destination)
            await sleep(1.2)
            for (title, enabled) in expected {
                guard let item = menuItem(title) else {
                    check("menu item \(title) exists", false)
                    continue
                }
                // As when the menu is opened.
                MacKeyRouter.refreshMenus(NSApp.mainMenu)
                check("\(title) is \(enabled ? "on" : "off") in \(destination)", item.isEnabled == enabled)
            }
        }
        if let pack = seededPack(in: workspace) {
            workspace.select(.pack(pack.id))
            await sleep(1.2)
            if let editor = MacE2EProbe.shared.dubEditor, let item = menuItem(MacStrings.Menu.nextLine),
               let menu = item.menu, let index = menu.items.firstIndex(of: item) {
                // From the top: every run records a take, so the first undubbed line drifts
                // towards the end, where there is no next line to go to.
                if let first = editor.pack.lines.first { editor.select(first) }
                await sleep(0.3)
                let before = editor.session.currentLineIndex
                MacKeyRouter.refreshMenus(NSApp.mainMenu)
                menu.performActionForItem(at: index)
                let moved = await waitUntil(1) { editor.session.currentLineIndex == before + 1 }
                check("Playback ▸ Next Line moves the editor on", moved)
            }
        }
        check("File has Import Dub Pack…", menuItem(MacStrings.Menu.importPack) != nil)
        check("File has New Session", menuItem(Strings.Main.newSession) != nil)
        check("View has the inspector switch", menuItem(MacStrings.Menu.hideInspector) != nil || menuItem(MacStrings.Menu.showInspector) != nil)
        check("Help has Rate", menuItem(Strings.ReviewBanner.rate) != nil)
    }

    // MARK: - Native

    private static func native(workspace: MacWorkspaceViewModel) async {
        section("native")
        guard let pack = seededPack(in: workspace) else { return }

        // Remembering where the window was, and what was opened lately.
        workspace.select(.pack(pack.id))
        _ = await waitUntil(3) { MacE2EProbe.shared.dubEditor != nil }
        await sleep(1)
        check("the selection is remembered for the next launch",
              UserDefaults.standard.string(forKey: "mac.lastSelection") == MacDestination.pack(pack.id).storageKey)
        check("the pack is first in Open Recent", workspace.recentPackIDs.first == pack.id)
        check("File has Open Recent", menuItem(MacStrings.Menu.openRecent) != nil)

        // Viewer modes and the scene transport from the keyboard.
        guard let editor = MacE2EProbe.shared.dubEditor else { return }
        focus(.linesTable)
        press(.key("2"), command: true, control: true)
        let original = await waitUntil(2) { editor.mode == .original }
        check("⌃⌘2 switches the viewer to Original", original)
        _ = await waitUntil(8) { editor.playback?.player.isPlaying == true }
        press(.space)
        _ = await waitUntil(1) { editor.playback?.player.isPlaying == false }
        editor.playback?.player.seek(to: 12)
        await sleep(0.3)
        press(.left)
        let back = await waitUntil(1) { abs(editor.session.scenePlayer.currentTime - 7) < 0.4 }
        check("← goes back five seconds", back, String(format: "%.2f", editor.session.scenePlayer.currentTime))
        press(.right)
        let forward = await waitUntil(1) { abs(editor.session.scenePlayer.currentTime - 12) < 0.4 }
        check("→ goes forward five seconds", forward, String(format: "%.2f", editor.session.scenePlayer.currentTime))
        press(.home)
        let home = await waitUntil(1) { editor.session.scenePlayer.currentTime < 0.2 }
        check("Home goes to the beginning", home)
        press(.key("1"), command: true, control: true)
        let line = await waitUntil(2) { editor.mode == .line }
        check("⌃⌘1 goes back to the line", line)

        // ⌘F searches the sidebar.
        press(.key("f"), command: true)
        await sleep(0.4)
        check("⌘F puts the cursor in the sidebar's search field", mainWindow?.firstResponder is NSTextView)
        workspace.searchText = "camp"
        await sleep(0.3)
        check("search narrows the packs", workspace.filteredPacks.count == 1 && workspace.filteredPacks.first?.title == "Camp Rules")
        await shot("21-search")
        workspace.searchText = ""
        press(.escape)
        mainWindow?.makeFirstResponder(nil)

        // ⌘/ shows every shortcut.
        press(.key("/"), command: true)
        let shortcuts = await waitUntil(2) { window(MacWindowID.shortcuts) != nil }
        check("⌘/ opens the keyboard shortcuts in a window of their own", shortcuts && mainWindow?.attachedSheet == nil)
        await shot("22-shortcuts", window: "shortcuts")
        pressTarget = window(MacWindowID.shortcuts)
        press(.escape)
        let closed = await waitUntil(2) { window(MacWindowID.shortcuts) == nil }
        check("Esc closes the shortcuts window", closed)
        pressTarget = nil
        window(MacWindowID.shortcuts)?.close()
        mainWindow?.makeKeyAndOrderFront(nil)

        // ⌘⌫ asks before deleting, and Esc keeps the pack.
        workspace.select(.pack(pack.id))
        await sleep(0.6)
        focus(.sidebar)
        press(.delete, command: true)
        let asked = await waitUntil(2) { workspace.pendingDeletion != nil }
        check("⌘⌫ asks before deleting the pack", asked)
        await shot("23-delete-confirm")
        press(.escape)
        let kept = await waitUntil(2) { workspace.pendingDeletion == nil }
        check("Esc keeps the pack", kept && workspace.pack(id: pack.id) != nil)

        // A pack opened from Finder or dropped on the Dock icon. The same pack again replaces
        // the installed one; what shows is the window going to it.
        workspace.select(.imitate)
        await sleep(1)
        log("E2E|OPENFILE|CampRules.zip")
        let opened = await waitUntil(90) {
            workspace.packs.first(where: { $0.title == "Camp Rules" }).map { workspace.selection == .pack($0.id) } ?? false
        }
        check("a pack opened from Finder is imported and opened", opened)
        await shot("24-opened-from-finder")
    }

    // MARK: - Pack Windows

    private static func packWindows(workspace: MacWorkspaceViewModel) async {
        section("windows")
        guard let pack = seededPack(in: workspace) else { return }
        workspace.select(.pack(pack.id))
        _ = await waitUntil(3) { MacE2EProbe.shared.dubEditor?.pack.id == pack.id }
        await sleep(0.6)

        // ⌥⌘O: the selected pack leaves the library for a window of its own.
        MacE2EProbe.shared.dubEditor = nil
        press(.key("o"), command: true, option: true)
        let opened = await waitUntil(4) { window(MacWindowID.pack) != nil && workspace.packsInWindows.contains(pack.id) }
        check("⌥⌘O opens the pack in a window of its own", opened)
        guard let packWindow = window(MacWindowID.pack) else { return }
        check("the library window stops showing the pack", workspace.selection != .pack(pack.id))
        check("the pack window is titled with the pack", packWindow.title.contains(pack.title), packWindow.title)
        _ = await waitUntil(4) { MacE2EProbe.shared.dubEditor?.pack.id == pack.id }
        guard let editor = MacE2EProbe.shared.dubEditor else { return }

        // Smaller than the library window, so the screenshot tool can tell them apart.
        packWindow.setContentSize(NSSize(width: 1100, height: 700))
        packWindow.makeKeyAndOrderFront(nil)
        await sleep(0.8)
        check("the menus follow the pack window", MacTransportHub.shared.current.toggleRecord != nil
              && MacTransportHub.shared.transport(for: packWindow) != nil)
        await shot("25-pack-window", window: "pack")

        // Keys typed into the pack window play that pack.
        pressTarget = packWindow
        press(.key("2"), command: true, control: true)
        let original = await waitUntil(2) { editor.mode == .original }
        check("⌃⌘2 in the pack window switches its viewer", original)
        press(.key("1"), command: true, control: true)
        _ = await waitUntil(2) { editor.mode == .line }

        // Its inspector is its own.
        let libraryInspector = workspace.showsInspector
        let before = UserDefaults.standard.object(forKey: "mac.packWindow.showsInspector") as? Bool ?? true
        press(.key("i"), command: true, option: true)
        let toggled = await waitUntil(1) {
            (UserDefaults.standard.object(forKey: "mac.packWindow.showsInspector") as? Bool ?? true) != before
        }
        check("⌥⌘I toggles the pack window's own inspector", toggled && workspace.showsInspector == libraryInspector)
        press(.key("i"), command: true, option: true)
        await sleep(0.4)
        pressTarget = nil

        // The pack chosen again in the library brings its window forward rather than opening
        // a second editor on it.
        mainWindow?.makeKeyAndOrderFront(nil)
        await sleep(0.4)
        workspace.select(.pack(pack.id))
        await sleep(0.8)
        check("choosing the pack again does not open it twice",
              workspace.selection != .pack(pack.id) && NSApp.windows.filter { $0.isVisible && MacWindowID.isKind(MacWindowID.pack, $0) }.count == 1)
        await shot("26-library-with-pack-window")

        packWindow.performClose(nil)
        let closed = await waitUntil(3) { window(MacWindowID.pack) == nil && !workspace.packsInWindows.contains(pack.id) }
        check("closing the pack window hands the pack back to the library", closed)
        workspace.select(.pack(pack.id))
        let back = await waitUntil(2) { workspace.selection == .pack(pack.id) }
        check("the library opens the pack again", back)
        mainWindow?.makeKeyAndOrderFront(nil)
        await sleep(0.6)
    }

    // MARK: - Settings

    private static func settingsWindow() async {
        section("settings")
        press(.key(","), command: true)
        let opened = await waitUntil(2) { NSApp.windows.contains { $0.isVisible && $0 !== mainWindow && $0.styleMask.contains(.titled) } }
        check("⌘, opens Settings", opened)
        await shot("19-settings", window: "settings")
        NSApp.windows.first { $0.isVisible && $0 !== mainWindow && $0.styleMask.contains(.titled) }?.close()
        mainWindow?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Window

    private static func windowSizes(workspace: MacWorkspaceViewModel) async {
        section("window")
        guard let window = mainWindow else { return }
        let destinations: [MacDestination] = [.reverse, .imitate] + (seededPack(in: workspace).map { [.pack($0.id)] } ?? [])
        for (label, size) in [("min", NSSize(width: 1180, height: 700)), ("large", NSSize(width: 1680, height: 1000))] {
            window.setContentSize(size)
            for destination in destinations {
                workspace.select(destination)
                await sleep(1.2)
                check("window survives \(label) size in \(destination)", window.isVisible)
                let name: String
                switch destination {
                case .reverse: name = "reverse"
                case .imitate: name = "imitate"
                default: name = "dub"
                }
                await shot("20-\(label)-\(name)")
            }
        }
        window.setContentSize(NSSize(width: 1280, height: 800))
    }

    // MARK: - Keys

    enum Key {
        case space, `return`, escape, up, down, left, right, home, tab, delete
        case key(String)

        var code: UInt16 {
            switch self {
            case .space: 49
            case .return: 36
            case .escape: 53
            case .up: 126
            case .down: 125
            case .left: 123
            case .right: 124
            case .home: 115
            case .tab: 48
            case .delete: 51
            case .key(let c):
                ["a": 0, "e": 14, "i": 34, "l": 37, "n": 45, "o": 31, "p": 35, "r": 15,
                 "1": 18, "2": 19, "3": 20, "4": 21, "?": 44, "=": 24, "-": 27, ",": 43, "f": 3, "/": 44][c] ?? 0
            }
        }

        var characters: String {
            switch self {
            case .space: " "
            case .return: "\r"
            case .escape: "\u{1b}"
            case .up: String(UnicodeScalar(NSUpArrowFunctionKey)!)
            case .down: String(UnicodeScalar(NSDownArrowFunctionKey)!)
            case .left: String(UnicodeScalar(NSLeftArrowFunctionKey)!)
            case .right: String(UnicodeScalar(NSRightArrowFunctionKey)!)
            case .home: String(UnicodeScalar(NSHomeFunctionKey)!)
            case .tab: "\t"
            case .delete: String(UnicodeScalar(NSBackspaceCharacter)!)
            case .key(let c): c
            }
        }

        var isArrow: Bool {
            switch self {
            case .up, .down, .left, .right, .home: true
            default: false
            }
        }
    }

    private static func press(_ key: Key, command: Bool = false, option: Bool = false, control: Bool = false, shift: Bool = false) {
        var flags: NSEvent.ModifierFlags = []
        if shift { flags.insert(.shift) }
        if command { flags.insert(.command) }
        if option { flags.insert(.option) }
        if control { flags.insert(.control) }
        if key.isArrow { flags.formUnion([.numericPad, .function]) }
        let window = pressTarget ?? NSApp.keyWindow ?? mainWindow
        for type in [NSEvent.EventType.keyDown, .keyUp] {
            guard let event = NSEvent.keyEvent(
                with: type,
                location: .zero,
                modifierFlags: flags,
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window?.windowNumber ?? 0,
                context: nil,
                characters: key.characters,
                charactersIgnoringModifiers: key.characters,
                isARepeat: false,
                keyCode: key.code
            ) else { continue }
            // Through the queue, like a real keystroke, so local monitors see it too.
            NSApp.postEvent(event, atStart: false)
        }
    }

    // MARK: - Helpers

    /// Gives keyboard focus to the sidebar or the lines table, the way a click would. Both are
    /// table views underneath; the sidebar has one column.
    private enum FocusTarget { case sidebar, linesTable }

    private static func focus(_ target: FocusTarget) {
        guard let window = mainWindow, let root = window.contentView?.superview else { return }
        var tables: [NSTableView] = []
        func collect(_ view: NSView) {
            if let table = view as? NSTableView { tables.append(table) }
            view.subviews.forEach(collect)
        }
        collect(root)
        let hit = target == .sidebar
            ? tables.first { $0.numberOfColumns == 1 }
            : tables.first { $0.numberOfColumns > 1 }
        if let hit {
            window.makeFirstResponder(hit)
            log("E2E|INFO|focused \(target) (\(Swift.type(of: hit)))")
        } else {
            log("E2E|INFO|no \(target) to focus among \(tables.map { "\(Swift.type(of: $0))/\($0.numberOfColumns)" })")
        }
    }

    /// Where keys go when a step means a window other than the one that happens to be key.
    private static var pressTarget: NSWindow?

    private static func window(_ kind: String) -> NSWindow? {
        NSApp.windows.first { $0.isVisible && MacWindowID.isKind(kind, $0) }
    }

    private static var mainWindow: NSWindow? {
        NSApp.windows.first { $0.identifier?.rawValue.hasPrefix("main") == true }
            ?? NSApp.windows.first { $0.isVisible && $0.frame.width > 900 }
    }

    private static func menuItem(_ title: String, in menu: NSMenu? = NSApp.mainMenu) -> NSMenuItem? {
        guard let menu else { return nil }
        for item in menu.items {
            if item.title == title { return item }
            if let found = menuItem(title, in: item.submenu) { return found }
        }
        return nil
    }

    private static func check(_ name: String, _ condition: Bool, _ detail: String = "") {
        if condition { passes += 1 } else { failures += 1 }
        log("E2E|\(condition ? "PASS" : "FAIL")|\(name)\(detail.isEmpty ? "" : "|\(detail)")")
    }

    private static func section(_ name: String) {
        log("E2E|SECTION|\(name)")
    }

    private static func shot(_ name: String, window: String = "main") async {
        log("E2E|SHOT|\(name)|\(window)")
        await sleep(3.2)
    }

    private static func log(_ line: String) {
        FileHandle.standardError.write(Data((line + "\n").utf8))
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
