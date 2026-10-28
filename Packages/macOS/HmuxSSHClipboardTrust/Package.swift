// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HmuxSSHClipboardTrust",
    platforms: [.macOS(.v14)],
    products: [.library(name: "HmuxSSHClipboardTrust", targets: ["HmuxSSHClipboardTrust"])],
    dependencies: [.package(path: "../HmuxSurfaceCatalogModel")],
    targets: [
        .target(
            name: "HmuxSSHClipboardTrust",
            dependencies: ["HmuxSurfaceCatalogModel"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "HmuxSSHClipboardTrustTests",
            dependencies: ["HmuxSSHClipboardTrust", "HmuxSurfaceCatalogModel"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
