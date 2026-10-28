// swift-tools-version: 6.0

import PackageDescription

// Platform-neutral Home render core (decisions IOS2/IOS3): text measurement
// and wrapping with Core Text, bubble and tail geometry, the fitted spring
// tokens, motion committed as Core Animation animations on plain CALayers,
// the layer tree, scroll and momentum, compose editing state, accessibility
// items and platform-neutral input. Imports Foundation, CoreGraphics,
// CoreText and QuartzCore only (no UIKit, no AppKit), so the iOS host
// (UIKit) and the Mac host (AppKit) embed the same root layer.
//
// Data comes from HmuxHomeCore (TranscriptItem, ConversationSummary,
// Participant); changes leave as HmuxHomeCore `HomeIntent`s (a `HomeOp` with
// its idempotency key). This module adds no model type of its own.
let package = Package(
    name: "HmuxHomeRender",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "HmuxHomeRender", targets: ["HmuxHomeRender"]),
    ],
    dependencies: [
        .package(path: "../HmuxHomeCore"),
    ],
    targets: [
        .target(
            name: "HmuxHomeRender",
            dependencies: [.product(name: "HmuxHomeCore", package: "HmuxHomeCore")],
            resources: [.process("Resources/Localizable.xcstrings")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "HmuxHomeRenderTests",
            dependencies: ["HmuxHomeRender", .product(name: "HmuxHomeCore", package: "HmuxHomeCore")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
