// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxSimulator",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "HmuxSimulator", type: .static, targets: ["HmuxSimulator"]),
        .library(name: "HmuxSimulatorUI", type: .static, targets: ["HmuxSimulatorUI"]),
        .library(name: "HmuxSimulatorWorker", type: .static, targets: ["HmuxSimulatorWorker"]),
    ],
    dependencies: [
        .package(path: "../HmuxFoundation"),
    ],
    targets: [
        .target(
            name: "HmuxSimulatorSystem",
            publicHeadersPath: "include"
        ),
        .target(
            name: "HmuxSimulator",
            dependencies: [
                "HmuxSimulatorSystem",
                .product(name: "HmuxFoundation", package: "HmuxFoundation"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .target(
            name: "HmuxSimulatorWorker",
            dependencies: ["HmuxSimulator", "HmuxSimulatorSystem"],
            resources: [
                .copy("Resources/CameraInjector"),
                .copy("Resources/SimulatorAXSettings"),
                .copy("Resources/WebInspector"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ],
            linkerSettings: [
                .linkedFramework("IOSurface"),
                .linkedFramework("CoreVideo"),
            ]
        ),
        .target(
            name: "HmuxSimulatorUI",
            dependencies: [
                "HmuxSimulator",
                "HmuxSimulatorSystem",
                .product(name: "HmuxFoundation", package: "HmuxFoundation"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ],
            linkerSettings: [
                .linkedFramework("ImageIO"),
                .linkedFramework("QuartzCore"),
                .linkedFramework("UniformTypeIdentifiers"),
            ]
        ),
        .testTarget(
            name: "HmuxSimulatorTests",
            dependencies: ["HmuxSimulator"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "HmuxSimulatorUITests",
            dependencies: [
                "HmuxSimulatorSystem",
                "HmuxSimulatorUI",
                "HmuxSimulatorWorker",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "HmuxSimulatorWorkerTests",
            dependencies: ["HmuxSimulator", "HmuxSimulatorWorker"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
