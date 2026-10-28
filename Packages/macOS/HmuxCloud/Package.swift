// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HmuxCloud",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "HmuxCloud", targets: ["HmuxCloud"]),
    ],
    dependencies: [
        .package(path: "../../Shared/HMUXAuthCore"),
        .package(path: "../../Shared/HmuxAuthRuntime"),
        .package(path: "../../Shared/HMUXMobileCore"),
        .package(path: "../HMUXDebugLog"),
        .package(path: "../HmuxCloudBannerCore"),
        .package(path: "../HmuxCloudImagePaste"),
        .package(path: "../HmuxCloudMachines"),
        .package(path: "../HmuxCloudTui"),
        .package(path: "../HmuxCloudTunnelCore"),
        .package(path: "../HmuxControlSocket"),
        .package(path: "../HmuxCore"),
        .package(path: "../HmuxFoundation"),
        .package(path: "../HmuxMobileHost"),
        .package(path: "../HmuxPhonePush"),
        .package(path: "../HmuxSettings"),
        .package(path: "../HmuxSurfaceCatalogModel"),
        .package(path: "../HmuxCloudResizeCore"),
        .package(path: "../HmuxTerminal")
    ],
    targets: [
        .target(
            name: "HmuxCloud",
            dependencies: [
                .product(name: "HmuxCloudResizeCore", package: "HmuxCloudResizeCore"),
                "HMUXAuthCore",
                "HmuxAuthRuntime",
                "HMUXMobileCore",
                "HMUXDebugLog",
                "HmuxCloudBannerCore",
                "HmuxCloudImagePaste",
                "HmuxCloudMachines",
                "HmuxCloudTui",
                "HmuxCloudTunnelCore",
                "HmuxControlSocket",
                "HmuxCore",
                "HmuxFoundation",
                "HmuxMobileHost",
                "HmuxPhonePush",
                "HmuxSettings",
                "HmuxSurfaceCatalogModel"
            ],
            // The files moved out of the app target unchanged; keep its language mode.
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "HmuxCloudTests",
            dependencies: [
                "HmuxCloud",
                "HmuxAuthRuntime",
                "HmuxCloudTui",
                "HmuxCloudTunnelCore",
                "HMUXMobileCore",
                "HmuxPhonePush",
                "HmuxSurfaceCatalogModel",
                .product(name: "HmuxCloudResizeCore", package: "HmuxCloudResizeCore"),
                // HmuxTerminal binds libghostty, which SwiftPM cannot link here.
                .product(name: "HmuxTerminalGhosttyRuntimeTestStubs", package: "HmuxTerminal")
            ],
            // Most of these tests moved from the app's test target, which builds in Swift 5 mode.
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
