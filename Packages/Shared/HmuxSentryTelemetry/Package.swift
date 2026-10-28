// swift-tools-version: 6.0

import PackageDescription

// `HmuxSentryTelemetry` is the shared (macOS + iOS) Sentry privacy and
// transport-telemetry layer. `HmuxSentryScrubbing` is the pure-Foundation
// value scrubber (no Sentry dependency) so it stays testable without linking
// the SDK; `HmuxSentryReporting` is the glue that routes Sentry `Event` /
// `Breadcrumb` / `Span` / `SentryLog` fields through that scrubber and bridges
// the HMUXMobileCore transport diagnostic stream into Sentry, so it links the
// Sentry SDK.
let package = Package(
    name: "HmuxSentryTelemetry",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxSentryScrubbing",
            targets: ["HmuxSentryScrubbing"]
        ),
        .library(
            name: "HmuxSentryReporting",
            targets: ["HmuxSentryReporting"]
        ),
    ],
    dependencies: [
        .package(path: "../HMUXMobileCore"),
        .package(
            url: "https://github.com/getsentry/sentry-cocoa.git",
            .upToNextMajor(from: "9.3.0")
        ),
    ],
    targets: [
        .target(
            name: "HmuxSentryScrubbing",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .target(
            name: "HmuxSentryReporting",
            dependencies: [
                "HmuxSentryScrubbing",
                "HMUXMobileCore",
                .product(name: "Sentry", package: "sentry-cocoa"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxSentryScrubbingTests",
            dependencies: ["HmuxSentryScrubbing"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxSentryReportingTests",
            dependencies: ["HmuxSentryReporting"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
