// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxAgentChatUI",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxAgentChatUI",
            targets: ["HmuxAgentChatUI"]
        ),
    ],
    dependencies: [
        .package(path: "../../Shared/HMUXMobileCore"),
        .package(path: "../../Shared/HmuxAgentChat"),
        .package(path: "../HmuxMobileSupport"),
        .package(path: "../HmuxMobileToast"),
        .package(
            url: "https://github.com/raspu/Highlightr.git",
            exact: "2.3.0"
        ),
    ],
    targets: [
        .target(
            name: "HmuxAgentChatUI",
            dependencies: [
                "HMUXMobileCore",
                "HmuxAgentChat",
                "HmuxMobileSupport",
                "HmuxMobileToast",
                .product(name: "Highlightr", package: "Highlightr"),
            ],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "HmuxAgentChatUITests",
            dependencies: ["HmuxAgentChatUI"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
