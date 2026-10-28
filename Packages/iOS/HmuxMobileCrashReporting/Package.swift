// swift-tools-version: 6.0

import PackageDescription

// `HmuxMobileCrashReporting` is the iOS crash telemetry leaf package. It owns
// the Sentry startup options for mobile, including watchdog termination,
// app-hang, and MetricKit diagnostics. It depends on the telemetry consent seam
// in `HMUXMobileCore`, making crash reporting and analytics sibling consumers
// of the same opt-out contract.
let package = Package(
    name: "HmuxMobileCrashReporting",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxMobileCrashReporting",
            targets: ["HmuxMobileCrashReporting"]
        ),
    ],
    dependencies: [
        .package(path: "../../Shared/HMUXMobileCore"),
        .package(path: "../../Shared/HmuxSentryTelemetry"),
        .package(
            url: "https://github.com/getsentry/sentry-cocoa.git",
            .upToNextMajor(from: "9.3.0")
        ),
    ],
    targets: [
        .target(
            name: "HmuxMobileCrashReporting",
            dependencies: [
                "HMUXMobileCore",
                .product(name: "HmuxSentryScrubbing", package: "HmuxSentryTelemetry"),
                .product(name: "HmuxSentryReporting", package: "HmuxSentryTelemetry"),
                .product(name: "Sentry", package: "sentry-cocoa"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxMobileCrashReportingTests",
            dependencies: [
                "HMUXMobileCore",
                "HmuxMobileCrashReporting",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
