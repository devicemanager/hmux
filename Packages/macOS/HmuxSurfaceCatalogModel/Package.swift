// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HmuxSurfaceCatalogModel",
    platforms: [.macOS(.v14)],
    products: [.library(name: "HmuxSurfaceCatalogModel", targets: ["HmuxSurfaceCatalogModel"])],
    dependencies: [
        .package(path: "../HMUXDebugLog"),
        .package(path: "../HmuxCore"),
        .package(path: "../../Shared/HMUXMobileCore")
    ],
    targets: [
        .target(
            name: "HmuxSurfaceCatalogModel",
            dependencies: ["HMUXDebugLog", "HmuxCore", "HMUXMobileCore"],
            // The files moved out of the app target unchanged; keep its language mode.
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(name: "HmuxSurfaceCatalogModelTests", dependencies: ["HmuxSurfaceCatalogModel"])
    ]
)
