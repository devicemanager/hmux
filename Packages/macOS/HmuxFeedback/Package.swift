// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxFeedback",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxFeedback",
            targets: ["HmuxFeedback"]
        ),
    ],
    dependencies: [
        .package(path: "../HmuxFoundation"),
    ],
    targets: [
        .target(
            name: "HmuxFeedback",
            dependencies: [
                "HmuxFoundation",
            ],
            resources: [
                // Folded from HmuxFeedbackUI: the composer's localized strings.
                .process("ComposerUI/Resources"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxFeedbackTests",
            dependencies: ["HmuxFeedback"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
