// swift-tools-version: 6.0

import PackageDescription

// Bridges hmux Cloud machines into the phone's workspace experience: Cloud
// workspaces become ordinary workspace rows in the shell store, and Cloud
// terminals are served through the same surface the paired-Mac path uses, so
// the workspace list, the detail chrome, the terminal and the composer are
// the same views with the same behavior.
//
// The Cloud domain package knows nothing about the shell, and the shell knows
// nothing about Cloud; this package is the only place both are named.
let swiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InternalImportsByDefault"),
]

let package = Package(
    name: "HmuxMobileCloudBridge",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "HmuxMobileCloudBridge", targets: ["HmuxMobileCloudBridge"]),
    ],
    dependencies: [
        .package(path: "../HmuxMobileCloud"),
        .package(path: "../HmuxMobileShell"),
        .package(path: "../HmuxMobileShellModel"),
        .package(path: "../HmuxMobileSupport"),
    ],
    targets: [
        .target(
            name: "HmuxMobileCloudBridge",
            dependencies: [
                "HmuxMobileCloud",
                "HmuxMobileShell",
                "HmuxMobileShellModel",
                "HmuxMobileSupport",
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "HmuxMobileCloudBridgeTests",
            dependencies: ["HmuxMobileCloudBridge", "HmuxMobileCloud", "HmuxMobileShell"],
            swiftSettings: swiftSettings
        ),
    ]
)
