//
//  MacStrings.swift
//  DubloonMac
//
//  The words only the Mac's own chrome uses: menus, panels and the welcome window. Everything
//  a game says is the shared `Strings`.
//

import Foundation

enum MacStrings {
    enum Sidebar {
        static let games = NSLocalizedString("mac.sidebar.games", comment: "Sidebar section listing the games")
        static let packs = NSLocalizedString("mac.sidebar.packs", comment: "Sidebar section listing the installed dub packs")
        static let sessions = NSLocalizedString("mac.sidebar.sessions", comment: "Sidebar section listing saved reverse-singing sessions")
    }

    enum Menu {
        static let importPack = NSLocalizedString("mac.menu.importPack", comment: "File menu: import a dub pack. Ends in an ellipsis")
        static let export = NSLocalizedString("mac.menu.export", comment: "File menu: export the dub as a video. Ends in an ellipsis")
        static let playback = NSLocalizedString("mac.menu.playback", comment: "Menu bar menu holding play, record and line navigation")
        static let playPause = NSLocalizedString("mac.menu.playPause", comment: "Playback menu: play or pause")
        static let record = NSLocalizedString("mac.menu.record", comment: "Playback menu: start or stop recording")
        static let listen = NSLocalizedString("mac.menu.listen", comment: "Playback menu: play the original line being dubbed or imitated")
        static let playTake = NSLocalizedString("mac.menu.playTake", comment: "Playback menu: play back the user's own take")
        static let previousLine = NSLocalizedString("mac.menu.previousLine", comment: "Playback menu: go to the previous line")
        static let nextLine = NSLocalizedString("mac.menu.nextLine", comment: "Playback menu: go to the next line")
        static let showInspector = NSLocalizedString("mac.menu.showInspector", comment: "View menu: show the inspector panel")
        static let hideInspector = NSLocalizedString("mac.menu.hideInspector", comment: "View menu: hide the inspector panel")
        static let openRecent = NSLocalizedString("mac.menu.openRecent", comment: "File menu: submenu of recently opened dub packs")
        static let clearRecent = NSLocalizedString("mac.menu.clearRecent", comment: "Last item of Open Recent: forget the list")
        static let open = NSLocalizedString("mac.menu.open", comment: "Context menu: open the pack or session")
        static let openInNewWindow = NSLocalizedString("mac.menu.openInNewWindow", comment: "File menu / context menu: open the dub pack in a window of its own")
        static let showInFinder = NSLocalizedString("mac.menu.showInFinder", comment: "Context menu: reveal the pack's folder in Finder")
        static let viewer = NSLocalizedString("mac.menu.viewer", comment: "View menu: submenu choosing what the dub viewer shows")
        static let zoomIn = NSLocalizedString("mac.menu.zoomIn", comment: "View menu: zoom the timeline in")
        static let zoomOut = NSLocalizedString("mac.menu.zoomOut", comment: "View menu: zoom the timeline out")
        static let skipBack = NSLocalizedString("mac.menu.skipBack", comment: "Playback menu: move the playhead back five seconds")
        static let skipForward = NSLocalizedString("mac.menu.skipForward", comment: "Playback menu: move the playhead forward five seconds")
        static let goToStart = NSLocalizedString("mac.menu.goToStart", comment: "Playback menu: move the playhead to the start of the scene")
        static let help = NSLocalizedString("mac.menu.help", comment: "Help menu: open the app's help window")
        static let shortcuts = NSLocalizedString("mac.menu.shortcuts", comment: "Help menu: open the list of keyboard shortcuts")
        static let find = NSLocalizedString("mac.menu.find", comment: "Edit menu: put the cursor in the sidebar's search field")
        static let deleteEllipsis = NSLocalizedString("mac.menu.delete", comment: "Context menu / Edit menu: delete the selected pack or session, asks first. Ends in an ellipsis")
    }

    enum Confirm {
        static let deletePackTitle = NSLocalizedString("mac.confirm.deletePack.title", comment: "Confirmation title before deleting a dub pack; %@ is its name")
        static let deletePackMessage = NSLocalizedString("mac.confirm.deletePack.message", comment: "Confirmation message before deleting a dub pack")
        static let deleteSessionTitle = NSLocalizedString("mac.confirm.deleteSession.title", comment: "Confirmation title before deleting a saved reverse-singing session")
        static let deleteSessionMessage = NSLocalizedString("mac.confirm.deleteSession.message", comment: "Confirmation message before deleting a saved session")
    }

    enum Shortcuts {
        static let file = NSLocalizedString("mac.shortcuts.file", comment: "Keyboard shortcuts window section: file commands")
        static let view = NSLocalizedString("mac.shortcuts.view", comment: "Keyboard shortcuts window section: view commands")
        nonisolated static let tipTitle = NSLocalizedString("mac.tip.shortcuts.title", comment: "One-time tip title about keyboard shortcuts")
        nonisolated static let tipMessage = NSLocalizedString("mac.tip.shortcuts.message", comment: "One-time tip about keyboard shortcuts")
    }

    enum Export {
        static let dragHint = NSLocalizedString("mac.export.dragHint", comment: "Under the exported video's icon: it can be dragged out to save it")
    }

    enum Panel {
        static let inspector = NSLocalizedString("mac.panel.inspector", comment: "Title of the inspector panel on the right")
        static let viewer = NSLocalizedString("mac.panel.viewer", comment: "Title of the panel that shows the picture")
        static let line = NSLocalizedString("mac.panel.line", comment: "One line of dialogue; also the viewer mode that works on one line")
        static let scene = NSLocalizedString("mac.panel.scene", comment: "The whole movie scene; a timeline track name")
        static let takes = NSLocalizedString("mac.panel.takes", comment: "Timeline track holding the user's recorded takes")
        static let character = NSLocalizedString("mac.panel.character", comment: "Column header: which character speaks the line")
        static let start = NSLocalizedString("mac.panel.start", comment: "Inspector: where the line starts in the scene")
        static let duration = NSLocalizedString("mac.panel.duration", comment: "Inspector or column header: how long something lasts")
        static let notDubbed = NSLocalizedString("mac.panel.notDubbed", comment: "Status of a line with no take yet")
        static let attempts = NSLocalizedString("mac.panel.attempts", comment: "Inspector: how many times the user sang it back")
        static let sound = NSLocalizedString("mac.panel.sound", comment: "Column header in the sound imitation browser: the sound's name")
        static let allSounds = NSLocalizedString("mac.panel.allSounds", comment: "Filter in the sound imitation browser: every category")
        static let compare = NSLocalizedString("mac.panel.compare", comment: "Title of the panel that draws the original sound above the user's imitation of it")
        static let emptyTitle = NSLocalizedString("mac.panel.emptyTitle", comment: "Shown when nothing is selected in the sidebar")
        static let emptyMessage = NSLocalizedString("mac.panel.emptyMessage", comment: "Shown when nothing is selected in the sidebar")
        static let clip = NSLocalizedString("mac.panel.clip", comment: "Inspector section about the video clip the user loaded")
        static let mix = NSLocalizedString("mac.panel.mix", comment: "Inspector section about how the voice and the video's own sound are mixed")
    }

    enum HomeVideo {
        static let fromPhotos = NSLocalizedString("mac.homeVideo.fromPhotos", comment: "Button / menu item: pick the video from the Photos library. Ends in an ellipsis")
        static let fromFile = NSLocalizedString("mac.homeVideo.fromFile", comment: "Button / menu item: pick a video file with the Open panel. Ends in an ellipsis")
        static let limit = NSLocalizedString("mac.homeVideo.limit", comment: "Small print in the empty viewer: clips up to a minute, and the video never leaves the Mac")
        static let emptyHint = NSLocalizedString("mac.homeVideo.hint.empty", comment: "Hint under the viewer before a video is chosen")
        static let dropHint = NSLocalizedString("mac.homeVideo.dropHint", comment: "Small print in the empty viewer: a video file can be dropped there")
    }

    enum Settings {
        static let general = NSLocalizedString("mac.settings.general", comment: "Settings tab: general preferences")
        static let recording = NSLocalizedString("mac.settings.recording", comment: "Settings tab: recording and camera preferences")
    }

    enum Search {
        static let prompt = NSLocalizedString("mac.search.prompt", comment: "Placeholder in the sidebar search field")
    }
}
