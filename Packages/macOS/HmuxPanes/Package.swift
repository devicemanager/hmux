// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxPanes",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxPanes",
            targets: ["HmuxPanes"]
        ),
    ],
    dependencies: [
        .package(path: "../../../vendor/bonsplit"),
    ],
    targets: [
        .target(
            name: "HmuxPanes",
            dependencies: [
                .product(name: "Bonsplit", package: "bonsplit"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxPanesTests",
            dependencies: ["HmuxPanes"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
