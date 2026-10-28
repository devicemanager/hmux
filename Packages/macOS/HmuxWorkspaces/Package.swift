// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxWorkspaces",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxWorkspaces",
            targets: ["HmuxWorkspaces"]
        ),
    ],
    dependencies: [
        .package(path: "../HmuxFoundation"),
        // WorkspaceGroupNewPlacement (the typed setting value for new
        // in-group workspace placement) is owned by HmuxSettings.
        .package(path: "../HmuxSettings"),
        // Bonsplit drives the Window/ tmux pane-overlay geometry.
        .package(path: "../../../vendor/bonsplit"),
        // HMUXDebugLog backs the Session/ snapshot-restore logging.
        .package(path: "../HMUXDebugLog"),
        // HmuxTestSupport backs FileOpen/ PreferredEditorService UI-test capture.
        .package(path: "../HmuxTestSupport"),
        // HMUXAgentLaunch owns the OMX HUD command match the Session/ restore policy shares with the CLI.
        .package(path: "../HMUXAgentLaunch"),
    ],
    targets: [
        .target(
            name: "HmuxWorkspaces",
            dependencies: [
                .product(name: "HmuxFoundation", package: "HmuxFoundation"),
                .product(name: "HmuxSettings", package: "HmuxSettings"),
                .product(name: "Bonsplit", package: "bonsplit"),
                .product(name: "HMUXDebugLog", package: "HMUXDebugLog"),
                .product(name: "HmuxTestSupport", package: "HmuxTestSupport"),
                .product(name: "HMUXAgentLaunch", package: "HMUXAgentLaunch"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxWorkspacesTests",
            dependencies: [
                "HmuxWorkspaces",
                .product(name: "HmuxFoundation", package: "HmuxFoundation"),
                .product(name: "Bonsplit", package: "bonsplit"),
                .product(name: "HmuxTestSupport", package: "HmuxTestSupport"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
