// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxMobileSimulatorStream",
    platforms: [
        .iOS(.v17),
        // macOS so the engine, mapping, and store logic unit-test locally;
        // the display view itself is UIKit-gated.
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxMobileSimulatorStream",
            targets: ["HmuxMobileSimulatorStream"]
        ),
    ],
    dependencies: [
        .package(path: "../../Shared/HmuxSimulatorStreamKit"),
        .package(path: "../../Shared/HMUXMobileCore"),
        .package(path: "../HmuxMobileRPC"),
    ],
    targets: [
        .target(
            name: "HmuxMobileSimulatorStream",
            dependencies: [
                "HmuxSimulatorStreamKit",
                "HMUXMobileCore",
                "HmuxMobileRPC",
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "HmuxMobileSimulatorStreamTests",
            dependencies: ["HmuxMobileSimulatorStream"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
