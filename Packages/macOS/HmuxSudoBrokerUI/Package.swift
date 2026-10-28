// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxSudoBrokerUI",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "HmuxSudoBrokerUI", targets: ["HmuxSudoBrokerUI"]),
    ],
    dependencies: [
        .package(path: "../HmuxSudoBroker"),
    ],
    targets: [
        .target(
            name: "HmuxSudoBrokerUI",
            dependencies: ["HmuxSudoBroker"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxSudoBrokerUITests",
            dependencies: ["HmuxSudoBrokerUI"]
        ),
    ]
)
