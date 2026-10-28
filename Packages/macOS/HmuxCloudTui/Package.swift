// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HmuxCloudTui",
    platforms: [.macOS(.v14)],
    products: [.library(name: "HmuxCloudTui", targets: ["HmuxCloudTui"])],
    dependencies: [
        .package(path: "../HmuxCloudImagePaste"),
        .package(path: "../HmuxFoundation"),
        .package(path: "../HmuxSurfaceCatalogModel"),
        .package(path: "../HmuxTerminal"),
        .package(path: "../../Shared/HmuxTerminalSizing")
    ],
    targets: [
        .target(
            name: "HmuxCloudTui",
            dependencies: ["HmuxCloudImagePaste", "HmuxFoundation", "HmuxSurfaceCatalogModel", "HmuxTerminal", "HmuxTerminalSizing"],
            // The files moved out of the app target unchanged; keep its language mode.
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "HmuxCloudTuiTests",
            dependencies: [
                "HmuxCloudTui",
                // HmuxTerminal binds libghostty, which SwiftPM cannot link here.
                .product(name: "HmuxTerminalGhosttyRuntimeTestStubs", package: "HmuxTerminal"),
            ]
        )
    ]
)
