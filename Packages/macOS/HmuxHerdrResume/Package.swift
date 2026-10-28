// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxHerdrResume",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxHerdrResume",
            targets: ["HmuxHerdrResume"]
        ),
    ],
    targets: [
        .target(
            name: "HmuxHerdrResume",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxHerdrResumeTests",
            dependencies: ["HmuxHerdrResume"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
