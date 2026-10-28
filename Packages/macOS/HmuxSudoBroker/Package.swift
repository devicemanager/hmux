// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxSudoBroker",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "HmuxSudoBroker", targets: ["HmuxSudoBroker"]),
    ],
    targets: [
        .target(
            name: "HmuxSudoBroker",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxSudoBrokerTests",
            dependencies: ["HmuxSudoBroker"]
        ),
    ]
)
