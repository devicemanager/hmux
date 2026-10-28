// swift-tools-version: 6.0

import PackageDescription

// `HmuxMobileAnalytics` is the concrete product and operational telemetry
// infrastructure: the fire-and-forget `AnalyticsEmitter` actor, pure
// sessionization and connection-edge throttle logic, and separate HTTP clients
// for PostHog product events and Axiom network outcomes. It conforms to the `AnalyticsEmitting` seam
// declared in `HMUXMobileCore`, so it depends only on that base package and
// Foundation — keeping the package graph an acyclic DAG. Everything it touches
// (the opt-out gate, the clock, `UserDefaults`, reachability, the base URL) is
// injected at construction so the actor is testable without the app.
let package = Package(
    name: "HmuxMobileAnalytics",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxMobileAnalytics",
            targets: ["HmuxMobileAnalytics"]
        ),
    ],
    dependencies: [
        .package(path: "../../Shared/HMUXMobileCore"),
    ],
    targets: [
        .target(
            name: "HmuxMobileAnalytics",
            dependencies: [
                "HMUXMobileCore",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxMobileAnalyticsTests",
            dependencies: [
                "HMUXMobileCore",
                "HmuxMobileAnalytics",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
