//
//  ReverseSingingApp.swift
//  ReverseSinging
//
//  Created by Josep Bordes Jové on 20/10/25.
//

import SwiftUI

@main
struct ReverseSingingApp: App {
    init() {
        // Configure audio session on app launch to prevent conflicts
        AudioSessionManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
