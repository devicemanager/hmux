// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxSidebar",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HmuxSidebar",
            targets: ["HmuxSidebar"]
        ),
    ],
    dependencies: [
        .package(path: "../HmuxFoundation"),
        .package(path: "../HmuxSwiftRender"),
        // HmuxExtensionKit backs the ExtensionHost/ sidebar-extension host view
        // and browser presenter.
        .package(path: "../HmuxExtensionKit"),
    ],
    targets: [
        .target(
            name: "HmuxSidebar",
            dependencies: [
                .product(name: "HmuxFoundation", package: "HmuxFoundation"),
                .product(name: "HmuxSwiftRender", package: "HmuxSwiftRender"),
                .product(name: "HmuxExtensionKit", package: "HmuxExtensionKit"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "HmuxSidebarTests",
            dependencies: [
                "HmuxSidebar",
                .product(name: "HmuxFoundation", package: "HmuxFoundation"),
                .product(name: "HmuxSwiftRender", package: "HmuxSwiftRender"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
