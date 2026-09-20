// swift-tools-version: 6.2

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("MemberImportVisibility"),
    // Keeps ZIPFoundation, CArchives and XiphCodecs out of the app's view: nothing they
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
                "XiphCodecs",
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
            ],
            swiftSettings: swiftSettings
        ),
        // The LZMA SDK's 7z decoder (public domain) and libarchive's RAR readers (BSD-2-Clause),
        // each behind a streaming extractor, and a zip reader that recovers archives whose index
        // is missing.
        .target(
            name: "CArchives",
            exclude: ["lzma-sdk/LICENSE.txt", "libarchive/COPYING"],
            cSettings: [
                .headerSearchPath("lzma-sdk"),
                .headerSearchPath("libarchive"),
                .define("Z7_PPMD_SUPPORT"),
                .define("Z7_EXTRACT_ONLY"),
                // libarchive reads its hand-written `libarchive/config.h` only when told to.
                .define("HAVE_CONFIG_H"),
            ],
            linkerSettings: [
                .linkedLibrary("z"),
                .linkedLibrary("bz2"),
            ]
        ),
        // libogg, libvorbis and libtheora's decoder, prebuilt by Vendor/build-xiph.sh.
        .binaryTarget(name: "XiphCodecs", path: "Vendor/XiphCodecs.xcframework"),
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
