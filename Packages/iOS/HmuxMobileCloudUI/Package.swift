// swift-tools-version: 6.0

import PackageDescription

// UI package for hmux Cloud on the phone: the Cloud section of the Computers
// screen, a machine's terminal catalog, and the terminal screen that feeds
// link bytes into the embedded libghostty view. Depends on the Cloud domain
// package and the terminal view only, never on the shell UI.
let swiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .enableUpcomingFeature("ExistentialAny"),
]

let package = Package(
    name: "HmuxMobileCloudUI",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "HmuxMobileCloudUI", targets: ["HmuxMobileCloudUI"]),
    ],
    dependencies: [
        .package(path: "../HmuxMobileBilling"),
        .package(path: "../HmuxMobileCloud"),
        .package(path: "../HmuxMobileSupport"),
        .package(path: "../HmuxMobileTerminal"),
        .package(path: "../../Shared/HMUXMobileCore"),
        .package(path: "../../Shared/HmuxTerminalClient"),
    ],
    targets: [
        .target(
            name: "HmuxMobileCloudUI",
            dependencies: [
                .product(name: "HmuxMobileBilling", package: "HmuxMobileBilling"),
                .product(name: "HmuxMobileBillingUI", package: "HmuxMobileBilling"),
                "HmuxMobileCloud",
                "HmuxMobileSupport",
                "HmuxMobileTerminal",
                "HMUXMobileCore",
                .product(name: "HmuxTerminalClientKit", package: "HmuxTerminalClient"),
                .product(name: "HmuxTerminalClientModel", package: "HmuxTerminalClient"),
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "HmuxMobileCloudUITests",
            dependencies: ["HmuxMobileCloudUI", "HmuxMobileCloud"],
            swiftSettings: swiftSettings
        ),
    ]
)
