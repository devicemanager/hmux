// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxMobileShell",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxMobileShell",
            targets: ["HmuxMobileShell"]
        ),
        .library(
            name: "HmuxMobileShellReleaseGateSupport",
            targets: ["HmuxMobileShellReleaseGateSupport"]
        ),
    ],
    dependencies: [
        .package(path: "../../Shared/HMUXMobileCore"),
        .package(path: "../../Shared/HmuxTerminalSizing"),
        .package(path: "../../Shared/HmuxWorkspacePresence"),
        .package(path: "../../Shared/HmuxAgentChat"),
        .package(path: "../../Shared/HmuxAgentQuestion"),
        .package(path: "../HmuxMobileChanges"),
        .package(path: "../HmuxMobileDiagnostics"),
        .package(path: "../HmuxMobileBrowserStream"),
        .package(path: "../HmuxMobilePairedMac"),
        .package(path: "../HmuxMobileRPC"),
        .package(path: "../HmuxMobileSSH"),
        .package(path: "../HmuxMobileShellModel"),
        .package(path: "../HmuxMobileSupport"),
        .package(path: "../HmuxMobileTerminalKit"),
        .package(path: "../HmuxMobileTransport"),
        .package(path: "../HmuxMobileTunnel"),
    ],
    targets: [
        .target(
            name: "HmuxMobileShell",
            dependencies: [
                "HMUXMobileCore",
                "HmuxTerminalSizing",
                "HmuxWorkspacePresence",
                "HmuxAgentChat",
                "HmuxAgentQuestion",
                "HmuxMobileChanges",
                "HmuxMobileDiagnostics",
                "HmuxMobileBrowserStream",
                "HmuxMobilePairedMac",
                "HmuxMobileRPC",
                "HmuxMobileSSH",
                "HmuxMobileShellModel",
                "HmuxMobileSupport",
                "HmuxMobileTerminalKit",
                "HmuxMobileTransport",
                "HmuxMobileTunnel",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .target(
            name: "HmuxMobileShellReleaseGateSupport",
            dependencies: [
                "HmuxMobileShell",
                "HMUXMobileCore",
                "HmuxAgentChat",
                "HmuxMobileRPC",
                "HmuxMobileShellModel",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxMobileShellTests",
            dependencies: [
                "HmuxMobileShell",
                "HmuxMobileShellReleaseGateSupport",
                "HMUXMobileCore",
                "HmuxWorkspacePresence",
                "HmuxAgentChat",
                "HmuxAgentQuestion",
                "HmuxMobileBrowserStream",
                "HmuxMobileChanges",
                "HmuxMobilePairedMac",
                "HmuxMobileRPC",
                "HmuxMobileShellModel",
                "HmuxMobileTransport",
                "HmuxTerminalSizing",
                "HmuxMobileTunnel",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
