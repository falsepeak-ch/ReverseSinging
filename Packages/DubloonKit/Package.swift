// swift-tools-version: 6.2

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("InternalImportsByDefault"),
]

/// Dubloon's reusable building blocks: nothing here knows about a pack, a screen or a service.
let package = Package(
    name: "DubloonKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DubAudio", targets: ["DubAudio"]),
        .library(name: "DubScoring", targets: ["DubScoring"]),
        .library(name: "DubCompositing", targets: ["DubCompositing"]),
        .library(name: "DubloonFoundation", targets: ["DubloonFoundation"]),
    ],
    targets: [
        // Loading, measuring, cleaning, levelling and mixing voice audio.
        .target(name: "DubAudio", swiftSettings: swiftSettings),
        // How close a take came to the line it replaces, and how close two recordings sound.
        .target(name: "DubScoring", dependencies: ["DubAudio"], swiftSettings: swiftSettings),
        // Where the scene and the booth sit in an exported frame.
        .target(name: "DubCompositing", swiftSettings: swiftSettings),
        // Trial, review and first-launch policies, and the clock formats the interface uses.
        .target(name: "DubloonFoundation", swiftSettings: swiftSettings),

        .testTarget(name: "DubAudioTests", dependencies: ["DubAudio"], swiftSettings: swiftSettings),
        .testTarget(name: "DubScoringTests", dependencies: ["DubScoring", "DubAudio"], swiftSettings: swiftSettings),
        .testTarget(name: "DubCompositingTests", dependencies: ["DubCompositing"], swiftSettings: swiftSettings),
        .testTarget(name: "DubloonFoundationTests", dependencies: ["DubloonFoundation"], swiftSettings: swiftSettings),
    ],
    swiftLanguageModes: [.v6]
)
