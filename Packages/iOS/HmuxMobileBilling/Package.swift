// swift-tools-version: 6.0

import PackageDescription

// Billing domain for the phone: StoreKit 2 subscriptions for hmux personal
// plans, verified and applied by the hmux web server
// (`docs/billing/ios-in-app-purchases.md`).
//
// `HmuxMobileBilling` holds the wire contract for `/api/billing/apple/*`, the
// StoreKit seam (`StoreKitClient`) and its live adapter, and the
// `@MainActor @Observable` ``BillingModel`` that sequences purchase, server
// delivery and `finish()`. `HmuxMobileBillingUI` holds the plans screen.
// Tests drive the model through fake StoreKit and API seams, so the package
// builds and tests on macOS without the app host or real StoreKit.
let swiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .enableUpcomingFeature("ExistentialAny"),
]

let package = Package(
    name: "HmuxMobileBilling",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "HmuxMobileBilling", targets: ["HmuxMobileBilling"]),
        .library(name: "HmuxMobileBillingUI", targets: ["HmuxMobileBillingUI"]),
    ],
    dependencies: [
        .package(path: "../../Shared/HMUXMobileCore"),
        .package(path: "../HmuxMobileSupport"),
    ],
    targets: [
        .target(
            name: "HmuxMobileBilling",
            dependencies: ["HMUXMobileCore"],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "HmuxMobileBillingUI",
            dependencies: [
                "HmuxMobileBilling",
                "HmuxMobileSupport",
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "HmuxMobileBillingTests",
            dependencies: ["HmuxMobileBilling", "HMUXMobileCore"],
            swiftSettings: swiftSettings
        ),
    ]
)
