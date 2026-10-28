// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxTerminal",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxTerminal",
            targets: ["HmuxTerminal"]
        ),
        // Lets other packages' test targets that link HmuxTerminal satisfy the
        // libghostty symbols the same way HmuxTerminalTests does.
        .library(
            name: "HmuxTerminalGhosttyRuntimeTestStubs",
            targets: ["HmuxTerminalGhosttyRuntimeTestStubs"]
        ),
    ],
    dependencies: [
        .package(path: "../HmuxFoundation"),
        .package(path: "../HmuxTerminalCore"),
        .package(path: "../HMUXDebugLog"),
        .package(path: "../HMUXAgentLaunch"),
        .package(path: "../../Shared/HMUXMobileCore"),
        .package(path: "../../Shared/HmuxTerminalPrediction"),
        .package(path: "../../Shared/HmuxGhosttyKit"),
        .package(path: "../../../vendor/bonsplit"),
    ],
    targets: [
        .target(
            name: "HmuxTerminal",
            dependencies: [
                .product(name: "HmuxFoundation", package: "HmuxFoundation"),
                .product(name: "HmuxTerminalCore", package: "HmuxTerminalCore"),
                .product(name: "HmuxGhosttyKit", package: "HmuxGhosttyKit"),
                .product(name: "HMUXDebugLog", package: "HMUXDebugLog"),
                .product(name: "HMUXAgentLaunch", package: "HMUXAgentLaunch"),
                .product(name: "HMUXMobileCore", package: "HMUXMobileCore"),
                .product(name: "HmuxTerminalPrediction", package: "HmuxTerminalPrediction"),
                .product(name: "Bonsplit", package: "bonsplit"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        // Test-only stand-in for the @_silgen_name libghostty symbol bound by
        // HmuxTerminalCore's GhosttyRuntimeCInterop: SwiftPM cannot link the
        // GhosttyKit macOS archive (its binary lacks the lib prefix), so the
        // test runner satisfies the link with a stub. The app links the real
        // GhosttyKit. Named distinctly from HmuxTerminalCore's own
        // GhosttyRuntimeTestStubs target (a different implementation for a
        // different test suite): SwiftPM target names must be unique across
        // the whole resolved graph, and both packages resolve together in
        // hmux.xcworkspace.
        .target(
            name: "HmuxTerminalGhosttyRuntimeTestStubs",
            path: "Tests/GhosttyRuntimeTestStubs"
        ),
        .testTarget(
            name: "HmuxTerminalTests",
            dependencies: [
                "HmuxTerminal",
                "HmuxTerminalGhosttyRuntimeTestStubs",
                .product(name: "HmuxTerminalCore", package: "HmuxTerminalCore"),
                .product(name: "HmuxGhosttyKit", package: "HmuxGhosttyKit"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
