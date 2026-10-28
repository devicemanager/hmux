// swift-tools-version: 6.0

import Foundation
import PackageDescription

// The Rust client (hmux-tui/crates/hmux-terminal-client) arrives as a prebuilt
// xcframework. Two sources, chosen when this manifest is evaluated:
//
//   * HmuxTerminalClient.xcframework next to this file, when a developer has
//     downloaded one from a workflow run (the directory is gitignored);
//   * otherwise the release zip pinned below, produced by
//     .github/workflows/hmux-terminal-client-xcframework.yml.
//
// Set HMUX_TERMINAL_CLIENT_FORCE_REMOTE_XCFRAMEWORK to ignore a local copy.
// Set HMUX_TERMINAL_CLIENT_MODEL_ONLY to build and test only the pure Swift
// model target, for a checkout with no binary available at all.
let releaseRepository = "manaflow-ai/cmux"
let releaseTag = "hmux-terminal-client-v0.1.0+6ba5de550cd4"
let releaseChecksum = "ecda518668cb64ad54c25869dd0996fc99e63c738bfa5e176b2b524d78290681"

let packageDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let localXcframework = packageDir.appendingPathComponent("HmuxTerminalClient.xcframework")
let forceRemote =
    ProcessInfo.processInfo.environment["HMUX_TERMINAL_CLIENT_FORCE_REMOTE_XCFRAMEWORK"] != nil
let useLocal =
    !forceRemote
    && FileManager.default.fileExists(atPath: localXcframework.appendingPathComponent("Info.plist").path)

let ffiBinary: Target =
    useLocal
    ? .binaryTarget(name: "HmuxTerminalClientFFI", path: "HmuxTerminalClient.xcframework")
    : .binaryTarget(
        name: "HmuxTerminalClientFFI",
        url:
            "https://github.com/\(releaseRepository)/releases/download/\(releaseTag)/HmuxTerminalClient.xcframework.zip",
        checksum: releaseChecksum)

let modelOnly = ProcessInfo.processInfo.environment["HMUX_TERMINAL_CLIENT_MODEL_ONLY"] != nil

let swiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InternalImportsByDefault"),
]

let package = Package(
    name: "HmuxTerminalClient",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: modelOnly
        ? [.library(name: "HmuxTerminalClientModel", targets: ["HmuxTerminalClientModel"])]
        : [
            .library(name: "HmuxTerminalClientKit", targets: ["HmuxTerminalClientKit"]),
            .library(name: "HmuxTerminalClientModel", targets: ["HmuxTerminalClientModel"]),
        ],
    targets: [
        // Pure Swift: result decoding and request shaping, testable without
        // the binary.
        .target(
            name: "HmuxTerminalClientModel",
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "HmuxTerminalClientModelTests",
            dependencies: ["HmuxTerminalClientModel"],
            swiftSettings: swiftSettings
        ),
    ] + (modelOnly
        ? []
        : [
            // The Swift face of the C ABI.
            .target(
                name: "HmuxTerminalClientKit",
                dependencies: ["HmuxTerminalClientModel", "HmuxTerminalClientFFI"],
                swiftSettings: swiftSettings,
                // What the static library needs from the system: Network for
                // iroh's netdev backend (nw_*), CoreFoundation and
                // SystemConfiguration for its network-path monitoring, and
                // Security for the random and trust primitives.
                linkerSettings: [
                    .linkedFramework("Network"),
                    .linkedFramework("CoreFoundation"),
                    .linkedFramework("Security"),
                    .linkedFramework("SystemConfiguration"),
                ]
            ),
            .testTarget(
                name: "HmuxTerminalClientKitTests",
                dependencies: ["HmuxTerminalClientKit"],
                swiftSettings: swiftSettings
            ),
            ffiBinary,
        ])
)
