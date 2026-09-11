//
//  BoothCamAnnouncementTests.swift
//  ReverseSingingTests
//
//  Who is told about the booth, and who is not
//

import Foundation
import Testing
@testable import ReverseSinging

@Suite("Booth Cam Announcement")
struct BoothCamAnnouncementTests {

    private static func makeDefaults() -> UserDefaults {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    /// An install that had finished onboarding before this build is an update, and is owed
    /// the note.
    @Test func anUpdatedInstallIsToldAboutTheBooth() {
        let defaults = Self.makeDefaults()
        defaults.set(true, forKey: "hasCompletedOnboarding")

        let announcement = BoothCamAnnouncement(defaults: defaults)
        announcement.resolveAtLaunch()

        #expect(announcement.isDue)
    }

    /// A fresh install gets onboarding and the tips instead.
    @Test func aFreshInstallIsNot() {
        let defaults = Self.makeDefaults()
        let announcement = BoothCamAnnouncement(defaults: defaults)

        announcement.resolveAtLaunch()

        #expect(announcement.isDue == false)
    }

    /// The question is asked once. A new user completes onboarding minutes after their first
    /// launch, which writes the marker the check reads; asking again on the second launch
    /// would announce an "update" to someone who has only ever had this build.
    @Test func aNewUserWhoLaterCompletesOnboardingIsStillNot() {
        let defaults = Self.makeDefaults()
        let announcement = BoothCamAnnouncement(defaults: defaults)

        announcement.resolveAtLaunch()
        #expect(announcement.isDue == false)

        defaults.set(true, forKey: "hasCompletedOnboarding")

        announcement.resolveAtLaunch()
        #expect(announcement.isDue == false,
                "the decision was re-made after the app wrote its own onboarding marker")
    }

    /// Someone who has already answered the primer has met the booth; announcing it to them
    /// would be telling them something they were the ones to switch on.
    @Test func someoneWhoHasMetThePrimerIsNot() {
        let defaults = Self.makeDefaults()
        defaults.set(true, forKey: "hasCompletedOnboarding")
        defaults.set(true, forKey: "booth.hasSeenPrimer")

        let announcement = BoothCamAnnouncement(defaults: defaults)
        announcement.resolveAtLaunch()

        #expect(announcement.isDue == false)
    }

    /// Once shown it stays shown, across launches.
    @Test func theNoteIsShownOnce() {
        let defaults = Self.makeDefaults()
        defaults.set(true, forKey: "hasCompletedOnboarding")

        let announcement = BoothCamAnnouncement(defaults: defaults)
        announcement.resolveAtLaunch()
        #expect(announcement.isDue)

        announcement.markShown()
        #expect(announcement.isDue == false)

        // Next launch.
        BoothCamAnnouncement(defaults: defaults).resolveAtLaunch()
        #expect(BoothCamAnnouncement(defaults: defaults).isDue == false)
    }
}
