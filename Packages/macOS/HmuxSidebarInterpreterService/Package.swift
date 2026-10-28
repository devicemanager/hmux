// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HmuxSidebarInterpreterService",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        // Host-side client + wire protocol the app links against.
        .library(
            name: "HmuxSidebarInterpreterClient",
            targets: ["HmuxSidebarInterpreterClient"]
        ),
        // The out-of-process worker that runs the untrusted interpreter.
        .executable(
            name: "hmux-sidebar-interpreter",
            targets: ["hmux-sidebar-interpreter"]
        ),
        // Headless protocol fixture for RenderWorkerClient supervision tests.
        .executable(
            name: "hmux-sidebar-render-fixture",
            targets: ["hmux-sidebar-render-fixture"]
        ),
        // Remote rendering: the faceless render-worker loop and the host-side
        // layer-hosting sidebar surface.
        .library(
            name: "HmuxSidebarRemoteRender",
            targets: ["HmuxSidebarRemoteRender"]
        ),
    ],
    dependencies: [
        .package(path: "../HmuxSwiftRender"),
        .package(path: "../HmuxSwiftRenderUI"),
    ],
    targets: [
        .target(
            name: "HmuxSidebarInterpreterClient",
            dependencies: ["HmuxSwiftRender"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .executableTarget(
            name: "hmux-sidebar-interpreter",
            dependencies: ["HmuxSidebarInterpreterClient"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .executableTarget(
            name: "hmux-sidebar-render-fixture",
            dependencies: ["HmuxSidebarInterpreterClient"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .target(
            name: "HmuxSidebarRemoteRender",
            dependencies: [
                "HmuxSidebarInterpreterClient",
                .product(name: "HmuxSwiftRenderUI", package: "HmuxSwiftRenderUI"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "HmuxSidebarInterpreterClientTests",
            dependencies: ["HmuxSidebarInterpreterClient"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "HmuxSidebarRemoteRenderTests",
            dependencies: ["HmuxSidebarRemoteRender"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
