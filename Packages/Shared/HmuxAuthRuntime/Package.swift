// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxAuthRuntime",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxAuthRuntime",
            targets: ["HmuxAuthRuntime"]
        ),
    ],
    dependencies: [
        .package(path: "../HMUXAuthCore"),
        .package(path: "../HMUXMobileCore"),
        .package(path: "../../../vendor/stack-auth-swift-sdk-prerelease"),
    ],
    targets: [
        .target(
            name: "HmuxAuthRuntime",
            dependencies: [
                "HMUXAuthCore",
                "HMUXMobileCore",
                .product(name: "StackAuth", package: "stack-auth-swift-sdk-prerelease"),
            ],
            swiftSettings: [
                .define("HMUX_DEV_AUTH", .when(configuration: .debug)),
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxAuthRuntimeTests",
            dependencies: [
                "HmuxAuthRuntime",
                .product(name: "StackAuth", package: "stack-auth-swift-sdk-prerelease"),
            ],
            swiftSettings: [
                .define("HMUX_DEV_AUTH", .when(configuration: .debug)),
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
