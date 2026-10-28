// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxMemoryPressure",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxMemoryPressure",
            targets: ["HmuxMemoryPressure"]
        ),
    ],
    dependencies: [
        .package(path: "../HmuxFoundation"),
    ],
    targets: [
        .target(
            name: "HmuxMemoryPressure",
            dependencies: ["HmuxFoundation"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxMemoryPressureTests",
            dependencies: ["HmuxMemoryPressure"]
        ),
    ]
)
