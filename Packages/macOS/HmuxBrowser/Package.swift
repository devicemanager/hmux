// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxBrowser",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxBrowser",
            targets: ["HmuxBrowser"]
        ),
    ],
    dependencies: [
        .package(path: "../HmuxFoundation"),
        .package(path: "../HMUXDebugLog"),
        .package(path: "../HmuxSettings"),
        .package(path: "../../../vendor/bonsplit"),
    ],
    targets: [
        .target(
            name: "HmuxBrowser",
            dependencies: [
                "HmuxFoundation",
                "HMUXDebugLog",
                "HmuxSettings",
                .product(name: "Bonsplit", package: "bonsplit"),
            ],
            resources: [
                .process("Resources"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxBrowserTests",
            dependencies: [
                "HmuxBrowser",
                "HmuxFoundation",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
