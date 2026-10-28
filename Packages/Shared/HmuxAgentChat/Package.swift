// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxAgentChat",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxAgentChat",
            targets: ["HmuxAgentChat"]
        ),
    ],
    targets: [
        .target(
            name: "HmuxAgentChat",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "HmuxAgentChatTests",
            dependencies: ["HmuxAgentChat"],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
