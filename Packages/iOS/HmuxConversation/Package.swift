// swift-tools-version: 6.0

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .enableUpcomingFeature("ExistentialAny"),
]

let package = Package(
    name: "HmuxConversation",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "HmuxConversationCore", targets: ["HmuxConversationCore"]),
        .library(name: "HmuxConversationUI", targets: ["HmuxConversationUI"]),
        .library(name: "HmuxConversationMacUI", targets: ["HmuxConversationMacUI"]),
    ],
    targets: [
        .target(
            name: "HmuxConversationCore",
            resources: [.process("Resources")],
            swiftSettings: swiftSettings
        ),
        .target(name: "HmuxConversationGeometry", dependencies: ["HmuxConversationCore"], swiftSettings: swiftSettings),
        .target(
            name: "HmuxConversationTranslation",
            dependencies: ["HmuxConversationCore"],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "HmuxConversationUI",
            dependencies: ["HmuxConversationCore", "HmuxConversationGeometry", "HmuxConversationTranslation"],
            resources: [.process("Resources")],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "HmuxConversationMacUI",
            dependencies: ["HmuxConversationCore", "HmuxConversationGeometry", "HmuxConversationTranslation"],
            resources: [.process("Resources")],
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "HmuxConversationLabMac",
            dependencies: ["HmuxConversationMacUI"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "HmuxConversationGeometryTests",
            dependencies: ["HmuxConversationGeometry"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "HmuxConversationCoreTests",
            dependencies: ["HmuxConversationCore", "HmuxConversationGeometry"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "HmuxConversationMacUITests",
            dependencies: ["HmuxConversationMacUI", "HmuxConversationCore"],
            swiftSettings: swiftSettings
        ),
    ]
)
