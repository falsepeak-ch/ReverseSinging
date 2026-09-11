// swift-tools-version: 6.2

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("MemberImportVisibility"),
    // Keeps ZIPFoundation, CArchives and XiphTheora out of the app's view: nothing they
    // declare can leak through DubPackKit's public API.
    .enableUpcomingFeature("InternalImportsByDefault"),
]

let package = Package(
    name: "DubPackKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DubPackKit", targets: ["DubPackKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation", from: "0.9.19"),
    ],
    targets: [
        .target(
            name: "DubPackKit",
            dependencies: [
                "CArchives",
                "XiphTheora",
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
            ],
            swiftSettings: swiftSettings
        ),
        // The LZMA SDK's 7z decoder (public domain) behind a streaming extractor, and a zip reader
        // that recovers archives whose index is missing.
        .target(
            name: "CArchives",
            exclude: ["lzma-sdk/LICENSE.txt"],
            cSettings: [
                .headerSearchPath("lzma-sdk"),
                .define("Z7_PPMD_SUPPORT"),
                .define("Z7_EXTRACT_ONLY"),
            ],
            linkerSettings: [
                .linkedLibrary("z"),
                .linkedLibrary("bz2"),
            ]
        ),
        // libogg + libtheora's decoder, prebuilt by Vendor/build-xiph.sh.
        .binaryTarget(name: "XiphTheora", path: "Vendor/XiphTheora.xcframework"),
        .testTarget(
            name: "DubPackKitTests",
            dependencies: [
                "DubPackKit",
                // Only to build zip fixtures in tests.
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
            ],
            resources: [.copy("Fixtures")],
            swiftSettings: swiftSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
