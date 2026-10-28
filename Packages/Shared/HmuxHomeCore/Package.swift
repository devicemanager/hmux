// swift-tools-version: 6.0

import PackageDescription

// Platform-neutral Home client core: the conversation model (same shapes as the
// conversation owner's wire contract), the HomeSource protocol every backend
// implements (mock, local daemon, cloud), the confirmed mirror + intent log,
// contact parsing for invites, and search over Home messages. No UIKit/AppKit,
// so it builds and tests on macOS with `swift test` and serves iOS and macOS.
let package = Package(
    name: "HmuxHomeCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "HmuxHomeCore", targets: ["HmuxHomeCore"]),
    ],
    dependencies: [
        // Agent questions (plans/hmux-next/agent-questions.md): the `question` part's model.
        .package(path: "../HmuxAgentQuestion"),
    ],
    targets: [
        .target(
            name: "HmuxHomeCore",
            dependencies: [.product(name: "HmuxAgentQuestion", package: "HmuxAgentQuestion")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // One condition-polling wait for every suite (no per-suite yield loops).
        .target(
            name: "HmuxHomeCoreTestSupport",
            path: "Tests/HmuxHomeCoreTestSupport",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "HmuxHomeCoreTests",
            dependencies: ["HmuxHomeCore", "HmuxHomeCoreTestSupport"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
