// swift-tools-version: 6.0

import PackageDescription

// The classic app's local Chief: an in-process conversation owner that keeps
// Home's Chief conversations on disk under one Chief home per build, runs
// each turn through a pluggable `ChiefBrain` (Claude Code, Codex, a fake in
// tests) and serves Home through `ChiefLocalSource`, a `HomeSource`.
let package = Package(
    name: "HmuxChief",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "HmuxChief", targets: ["HmuxChief"]),
    ],
    dependencies: [
        .package(path: "../../Shared/HmuxHomeCore"),
        .package(path: "../../Shared/HmuxAgentQuestion"),
    ],
    targets: [
        .target(
            name: "HmuxChief",
            dependencies: [
                .product(name: "HmuxHomeCore", package: "HmuxHomeCore"),
                .product(name: "HmuxAgentQuestion", package: "HmuxAgentQuestion"),
            ],
            resources: [
                .process("Resources/Localizable.xcstrings"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
            ]
        ),
        .testTarget(
            name: "HmuxChiefTests",
            dependencies: [
                "HmuxChief",
                .product(name: "HmuxHomeCore", package: "HmuxHomeCore"),
                .product(name: "HmuxAgentQuestion", package: "HmuxAgentQuestion"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
            ]
        ),
    ]
)
