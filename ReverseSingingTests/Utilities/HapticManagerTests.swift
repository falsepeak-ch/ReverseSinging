//
//  HapticManagerTests.swift
//  ReverseSingingTests
//

import Testing
import Foundation
@testable import ReverseSinging

@Suite("HapticManager Tests")
struct HapticManagerTests {

    @Test func sharedInstance() {
        let manager1 = HapticManager.shared
        let manager2 = HapticManager.shared

        #expect(manager1 === manager2)
    }

    @Test func hapticMethodsExist() {
        let manager = HapticManager.shared

        // Just verify methods exist and don't crash
        manager.light()
        manager.medium()
        manager.heavy()
        manager.soft()
        manager.rigid()
        manager.success()
        manager.warning()
        manager.error()
        manager.selection()
    }
}
