// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HmuxAgentJournal",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxAgentJournal",
            targets: ["HmuxAgentJournal"]
        ),
    ],
    targets: [
        .target(
            name: "HmuxAgentJournal",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxAgentJournalTests",
            dependencies: ["HmuxAgentJournal"]
        ),
    ]
)
