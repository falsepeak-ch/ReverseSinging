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
        static let emptyTitle = NSLocalizedString("mac.panel.emptyTitle", comment: "Shown when nothing is selected in the sidebar")
        static let emptyMessage = NSLocalizedString("mac.panel.emptyMessage", comment: "Shown when nothing is selected in the sidebar")
    }

    enum Settings {
        static let general = NSLocalizedString("mac.settings.general", comment: "Settings tab: general preferences")
        static let recording = NSLocalizedString("mac.settings.recording", comment: "Settings tab: recording and camera preferences")
    }

    enum Welcome {
        static let notNow = NSLocalizedString("mac.welcome.notNow", comment: "Skip the microphone step of the welcome window")
    }
}
