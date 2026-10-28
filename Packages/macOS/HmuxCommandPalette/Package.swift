// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxCommandPalette",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxCommandPalette",
            targets: ["HmuxCommandPalette"]
        ),
    ],
    dependencies: [
        // HmuxFoundation backs the FocusGuards/ command-palette focus-stealing
        // NSResponder/NSView guards.
        .package(path: "../HmuxFoundation"),
    ],
    targets: [
        .target(
            name: "HmuxCommandPalette",
            dependencies: [
                .product(name: "HmuxFoundation", package: "HmuxFoundation"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxCommandPaletteTests",
            dependencies: [
                "HmuxCommandPalette",
                .product(name: "HmuxFoundation", package: "HmuxFoundation"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
