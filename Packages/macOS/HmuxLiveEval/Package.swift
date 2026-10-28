// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxLiveEval",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxLiveEval",
            targets: ["HmuxLiveEval"]
        ),
        .executable(
            name: "LiveEvalDemo",
            targets: ["LiveEvalDemo"]
        ),
    ],
    dependencies: [
        .package(path: "../HmuxSwiftRender"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
    ],
    targets: [
        .target(
            name: "HmuxLiveEval",
            dependencies: [
                .product(name: "HmuxSwiftRender", package: "HmuxSwiftRender"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftOperators", package: "swift-syntax"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .executableTarget(
            name: "LiveEvalDemo",
            dependencies: ["HmuxLiveEval"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "HmuxLiveEvalTests",
            dependencies: ["HmuxLiveEval"]
        ),
    ]
)
