// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxHive",
    platforms: [.macOS(.v14)],
    products: [.library(name: "HmuxHive", targets: ["HmuxHive"])],
    dependencies: [
        .package(path: "../../Shared/HMUXMobileCore"),
        .package(path: "../../iOS/HmuxMobilePairedMac"),
        .package(path: "../../iOS/HmuxMobileRPC"),
        .package(path: "../../iOS/HmuxMobileTransport"),
    ],
    targets: [
        .target(name: "HmuxHive", dependencies: [
            "HMUXMobileCore",
            "HmuxMobilePairedMac", "HmuxMobileRPC", "HmuxMobileTransport",
        ], swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(name: "HmuxHiveTests", dependencies: [
            "HmuxHive", "HMUXMobileCore", "HmuxMobileRPC", "HmuxMobilePairedMac",
        ], swiftSettings: [.swiftLanguageMode(.v6)]),
    ]
)
