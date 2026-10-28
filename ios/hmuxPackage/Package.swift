// swift-tools-version: 6.0

import PackageDescription

// `hmuxFeature` is the iOS composition-root package, not a catch-all. After the
// 5079 refactor it holds only the runtime DI bundle (`HMUXMobileRuntime`), the
// auth composition (`MobileAuthComposition` over `HmuxAuthRuntime`), and the
// root scene (`HMUXMobileRootScene`). The store, RPC, persistence, terminal,
// and view code were lifted into the focused packages it depends on below. See
// README.md for the per-type role table.
let package = Package(
    name: "hmuxFeature",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "hmuxFeature",
            targets: ["hmuxFeature"]
        ),
        .library(
            name: "HmuxIrohReleaseGateSupport",
            targets: ["HmuxIrohReleaseGateSupport"]
        ),
    ],
    dependencies: [
        .package(path: "../../Packages/Shared/HMUXAuthCore"),
        .package(path: "../../Packages/Shared/HmuxAuthRuntime"),
        .package(path: "../../Packages/macOS/HmuxPhonePush"),
        .package(path: "../../Packages/Shared/HmuxClientConfig"),
        .package(path: "../../Packages/Shared/HmuxIrohTransport"),
        .package(path: "../../Packages/Shared/HmuxIrxTransport"),
        .package(path: "../../Packages/Shared/HMUXMobileCore"),
        .package(path: "../../Packages/iOS/HmuxMobileAnalytics"),
        .package(path: "../../Packages/iOS/HmuxMobileBilling"),
        .package(path: "../../Packages/iOS/HmuxMobileBrowser"),
        .package(path: "../../Packages/iOS/HmuxMobileBrowserStream"),
        .package(path: "../../Packages/iOS/HmuxMobileCamera"),
        .package(path: "../../Packages/iOS/HmuxMobileCloud"),
        .package(path: "../../Packages/iOS/HmuxMobileCloudBridge"),
        .package(path: "../../Packages/iOS/HmuxMobileCloudUI"),
        .package(path: "../../Packages/iOS/HmuxMobileCrashReporting"),
        .package(path: "../../Packages/iOS/HmuxMobileDiagnostics"),
        .package(path: "../../Packages/iOS/HmuxMobilePairedMac"),
        .package(path: "../../Packages/iOS/HmuxMobileRPC"),
        .package(path: "../../Packages/iOS/HmuxMobileShell"),
        .package(path: "../../Packages/iOS/HmuxMobileShellModel"),
        .package(path: "../../Packages/iOS/HmuxMobileShellUI"),
        .package(path: "../../Packages/iOS/HmuxMobileSimulatorStream"),
        .package(path: "../../Packages/iOS/HmuxMobileSupport"),
        .package(path: "../../Packages/iOS/HmuxMobileTerminal"),
        .package(path: "../../Packages/iOS/HmuxMobileToast"),
        .package(path: "../../Packages/iOS/HmuxMobileTerminalKit"),
        .package(path: "../../Packages/iOS/HmuxMobileTransport"),
        .package(path: "../../Packages/iOS/HmuxMobileWorkspace"),
        .package(path: "../../vendor/stack-auth-swift-sdk-prerelease"),
    ],
    targets: [
        .target(
            name: "hmuxFeature",
            dependencies: [
                "HMUXAuthCore",
                "HmuxAuthRuntime",
                "HmuxPhonePush",
                "HmuxClientConfig",
                "HmuxIrohTransport",
                "HmuxIrxTransport",
                "HMUXMobileCore",
                "HmuxMobileAnalytics",
                .product(name: "HmuxMobileBilling", package: "HmuxMobileBilling"),
                .product(name: "HmuxMobileBillingUI", package: "HmuxMobileBilling"),
                "HmuxMobileBrowser",
                "HmuxMobileBrowserStream",
                "HmuxMobileCamera",
                "HmuxMobileCloud",
                "HmuxMobileCloudBridge",
                "HmuxMobileCloudUI",
                "HmuxMobileCrashReporting",
                "HmuxMobileDiagnostics",
                "HmuxMobilePairedMac",
                "HmuxMobileRPC",
                "HmuxMobileShell",
                "HmuxMobileShellModel",
                "HmuxMobileShellUI",
                "HmuxMobileSimulatorStream",
                "HmuxMobileSupport",
                "HmuxMobileTerminal",
                "HmuxMobileTerminalKit",
                "HmuxMobileToast",
                "HmuxMobileTransport",
                "HmuxMobileWorkspace",
                .product(name: "StackAuth", package: "stack-auth-swift-sdk-prerelease"),
            ],
            swiftSettings: [
                .define("HMUX_DEV_AUTH", .when(configuration: .debug)),
                .swiftLanguageMode(.v6),
            ]
        ),
        .target(
            name: "HmuxIrohReleaseGateSupport",
            dependencies: [
                "hmuxFeature",
                "HMUXMobileCore",
                "HmuxIrohTransport",
                "HmuxMobileShell",
                .product(
                    name: "HmuxMobileShellReleaseGateSupport",
                    package: "HmuxMobileShell"
                ),
                "HmuxMobileShellModel",
                "HmuxMobileShellUI",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "hmuxFeatureTests",
            dependencies: [
                "hmuxFeature",
                "HmuxIrohReleaseGateSupport",
                "HMUXAuthCore",
                "HmuxAuthRuntime",
                "HmuxPhonePush",
                "HmuxClientConfig",
                "HmuxIrohTransport",
                "HmuxIrxTransport",
                "HMUXMobileCore",
                "HmuxMobileAnalytics",
                "HmuxMobileBrowser",
                "HmuxMobileBrowserStream",
                "HmuxMobileCamera",
                "HmuxMobileCloud",
                "HmuxMobileCloudBridge",
                "HmuxMobileCloudUI",
                "HmuxMobileCrashReporting",
                "HmuxMobileDiagnostics",
                "HmuxMobilePairedMac",
                "HmuxMobileRPC",
                "HmuxMobileShell",
                "HmuxMobileShellModel",
                "HmuxMobileShellUI",
                "HmuxMobileSimulatorStream",
                "HmuxMobileSupport",
                "HmuxMobileTerminal",
                "HmuxMobileTerminalKit",
                "HmuxMobileToast",
                "HmuxMobileTransport",
                "HmuxMobileWorkspace",
                .product(name: "StackAuth", package: "stack-auth-swift-sdk-prerelease"),
            ],
            swiftSettings: [
                .define("HMUX_DEV_AUTH", .when(configuration: .debug)),
            ]
        ),
    ]
)
