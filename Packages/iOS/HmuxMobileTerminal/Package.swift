// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxMobileTerminal",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "HmuxMobileTerminal",
            targets: ["HmuxMobileTerminal"]
        ),
    ],
    dependencies: [
        .package(path: "../../Shared/HMUXMobileCore"),
        .package(path: "../../Shared/HmuxAgentChat"),
        .package(path: "../../Shared/HmuxGhosttyKit"),
        .package(path: "../HmuxMobileDiagnostics"),
        .package(path: "../HmuxMobileSupport"),
        .package(path: "../HmuxMobileTerminalKit"),
    ],
    targets: [
        .target(
            name: "HmuxMobileTerminal",
            dependencies: [
                "HMUXMobileCore",
                "HmuxAgentChat",
                "HmuxMobileDiagnostics",
                "HmuxMobileSupport",
                "HmuxMobileTerminalKit",
                // The same libghostty the Mac links; iOS feeds raw PTY bytes
                // straight into ghostty_surface_* so the phone runs the
                // identical terminal core.
                .product(name: "HmuxGhosttyKit", package: "HmuxGhosttyKit"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "HmuxMobileTerminalTests",
            dependencies: ["HmuxMobileTerminal", "HmuxMobileTerminalKit"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ],
            // GhosttyKit's static lib carries C++ objects (glslang); the
            // standalone xctest bundle must link the C++ runtime itself.
            linkerSettings: [
                .linkedLibrary("c++"),
            ]
        ),
    ]
)
