// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxSettingsUI",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxSettingsUI",
            targets: ["HmuxSettingsUI"]
        ),
    ],
    dependencies: [
        .package(path: "../../Shared/HMUXMobileCore"),
        .package(path: "../HmuxFoundation"),
        .package(path: "../HmuxSettings"),
    ],
    targets: [
        .target(
            name: "HmuxSettingsUI",
            dependencies: [
                "HMUXMobileCore",
                .product(name: "HmuxFoundation", package: "HmuxFoundation"),
                .product(name: "HmuxSettings", package: "HmuxSettings"),
            ],
            resources: [
                .process("Resources/Localizable.xcstrings"),
                .copy("Resources/CustomSidebars"),
                .copy("Resources/CustomSidebarTemplatePreviews"),
            ]
        ),
        .testTarget(
            name: "HmuxSettingsUITests",
            dependencies: [
                "HMUXMobileCore",
                "HmuxSettingsUI",
                "HmuxSettings",
                .product(name: "HmuxFoundation", package: "HmuxFoundation"),
            ]
        ),
    ]
)
