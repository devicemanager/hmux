import Foundation
import Testing

@testable import HmuxSettings

/// Channel/override/startup rules for the control socket path.
///
/// These moved out of the app-host `hmuxTests` bundle: every assertion here is
/// on `HmuxSettings` value types only, so the app host bought nothing.
/// ``SocketControlSettingsTests`` covers mode resolution and the XCTest socket
/// fallback; this suite covers bundle-channel defaults, override refusal, and
/// the pre-listener startup probe.
@Suite struct SocketControlSettingsChannelTests {
    // MARK: - Mode and permissions

    @Test func migrateModeAcceptsEveryCanonicalSpelling() {
        #expect(SocketControlSettings.migrateMode("off") == .off)
        #expect(SocketControlSettings.migrateMode("hmuxOnly") == .hmuxOnly)
        #expect(SocketControlSettings.migrateMode("automation") == .automation)
        #expect(SocketControlSettings.migrateMode("password") == .password)
        #expect(SocketControlSettings.migrateMode("allow-all") == .allowAll)
    }

    @Test func socketFilePermissionsAreRestrictiveExceptForAllowAll() {
        #expect(SocketControlMode.off.socketFilePermissions == 0o600)
        #expect(SocketControlMode.hmuxOnly.socketFilePermissions == 0o600)
        #expect(SocketControlMode.automation.socketFilePermissions == 0o600)
        #expect(SocketControlMode.password.socketFilePermissions == 0o600)
        #expect(SocketControlMode.allowAll.socketFilePermissions == 0o666)
    }

    @Test func invalidEnvSocketModeDoesNotOverrideUserMode() {
        #expect(
            SocketControlSettings.envOverrideMode(
                environment: ["HMUX_SOCKET_MODE": "definitely-not-a-mode"]
            ) == nil
        )
        #expect(
            SocketControlSettings.effectiveMode(
                userMode: .password,
                environment: ["HMUX_SOCKET_MODE": "definitely-not-a-mode"]
            ) == .password
        )
    }

    // MARK: - Ambient override handling per channel

    @Test func stableReleaseIgnoresAmbientSocketOverrideByDefault() {
        let path = SocketControlSettings.socketPath(
            environment: [
                "HMUX_TAG": "stray-tag",
                "HMUX_SOCKET_PATH": "/tmp/hmux-debug-issue-153-tmux-compat.sock",
            ],
            bundleIdentifier: "com.hmuxterm.app",
            isDebugBuild: false,
            probeStableDefaultPathEntry: { _ in .missing }
        )

        #expect(path == SocketControlSettings.stableDefaultSocketPath)
    }

    @Test func taggedDebugLaunchUsesTagDefaultWhenNoOverrideIsProvided() {
        let path = SocketControlSettings.socketPath(
            environment: ["HMUX_TAG": "my-tag"],
            bundleIdentifier: "com.hmuxterm.app.debug",
            isDebugBuild: true
        )

        #expect(path == "/tmp/hmux-debug-my-tag.sock")
    }

    @Test func taggedDebugLaunchStillHonorsSocketOverride() {
        let path = SocketControlSettings.socketPath(
            environment: [
                "HMUX_TAG": "my-tag",
                "HMUX_SOCKET_PATH": "/tmp/hmux-debug-forced.sock",
            ],
            bundleIdentifier: "com.hmuxterm.app.debug",
            isDebugBuild: true
        )

        #expect(path == "/tmp/hmux-debug-forced.sock")
    }

    @Test func nightlyReleaseUsesDedicatedDefaultAndIgnoresAmbientSocketOverride() {
        let path = SocketControlSettings.socketPath(
            environment: ["HMUX_SOCKET_PATH": "/tmp/hmux-debug-issue-153-tmux-compat.sock"],
            bundleIdentifier: "com.hmuxterm.app.nightly",
            isDebugBuild: false,
            probeStableDefaultPathEntry: { _ in .missing }
        )

        #expect(path == "/tmp/hmux-nightly.sock")
    }

    @Test func taggedDebugBundleKeepsMatchingSocketOverrideWithoutOptInFlag() {
        let path = SocketControlSettings.socketPath(
            environment: ["HMUX_SOCKET_PATH": "/tmp/hmux-debug-my-tag.sock"],
            bundleIdentifier: "com.hmuxterm.app.debug.my-tag",
            isDebugBuild: false
        )

        #expect(path == "/tmp/hmux-debug-my-tag.sock")
    }

    @Test func taggedDebugBundleIgnoresSocketOverrideInheritedFromDifferentHmuxBundle() {
        let path = SocketControlSettings.socketPath(
            environment: [
                "HMUX_BUNDLE_ID": "com.hmuxterm.app.nightly",
                "HMUX_SOCKET_PATH": "/tmp/hmux-nightly.sock",
            ],
            bundleIdentifier: "com.hmuxterm.app.debug.issue.4355.hmux.themes.set.state.dependent",
            isDebugBuild: true
        )

        #expect(path == "/tmp/hmux-debug-issue-4355-hmux-themes-set-state-dependent.sock")
    }

    @Test func taggedDebugBundleIgnoresMismatchedInheritedSocketOverride() {
        let path = SocketControlSettings.socketPath(
            environment: [
                "HMUX_SOCKET_PATH": "/tmp/hmux-nightly.sock",
                "HMUX_BUNDLE_ID": "com.hmuxterm.app.nightly",
            ],
            bundleIdentifier: "com.hmuxterm.app.debug.fix-grok-notifications",
            isDebugBuild: false
        )

        #expect(path == "/tmp/hmux-debug-fix-grok-notifications.sock")
    }

    @Test func taggedDebugBundleCanOptInToMismatchedSocketOverride() {
        let path = SocketControlSettings.socketPath(
            environment: [
                "HMUX_SOCKET_PATH": "/tmp/hmux-nightly.sock",
                "HMUX_BUNDLE_ID": "com.hmuxterm.app.nightly",
                "HMUX_ALLOW_SOCKET_OVERRIDE": "1",
            ],
            bundleIdentifier: "com.hmuxterm.app.debug.fix-grok-notifications",
            isDebugBuild: false
        )

        #expect(path == "/tmp/hmux-nightly.sock")
    }

    @Test func stagingBundleHonorsSocketOverrideWithoutOptInFlag() {
        let path = SocketControlSettings.socketPath(
            environment: ["HMUX_SOCKET_PATH": "/tmp/hmux-staging-my-tag.sock"],
            bundleIdentifier: "com.hmuxterm.app.staging.my-tag",
            isDebugBuild: false
        )

        #expect(path == "/tmp/hmux-staging-my-tag.sock")
    }

    @Test func stableReleaseCanOptInToSocketOverride() {
        let path = SocketControlSettings.socketPath(
            environment: [
                "HMUX_SOCKET_PATH": "/tmp/hmux-debug-forced.sock",
                "HMUX_ALLOW_SOCKET_OVERRIDE": "1",
            ],
            bundleIdentifier: "com.hmuxterm.app",
            isDebugBuild: false,
            probeStableDefaultPathEntry: { _ in .missing }
        )

        #expect(path == "/tmp/hmux-debug-forced.sock")
    }

    // MARK: - Stable-socket hijack refusal

    @Test func taggedDebugBundleRefusesStableSocketOverrideEvenWithOptInFlag() {
        let path = SocketControlSettings.socketPath(
            environment: [
                "HMUX_SOCKET_PATH": SocketControlSettings.stableDefaultSocketPath,
                "HMUX_ALLOW_SOCKET_OVERRIDE": "1",
            ],
            bundleIdentifier: "com.hmuxterm.app.debug.sockguard",
            isDebugBuild: false
        )

        #expect(path == "/tmp/hmux-debug-sockguard.sock")
    }

    @Test func taggedDebugBundleRefusesUserScopedStableSocketOverrideEvenWithOptInFlag() {
        let aliases = [
            SocketControlSettings.userScopedStableSocketPath(currentUserID: 501),
            SocketControlSettings.legacyUserScopedStableSocketPath(currentUserID: 501),
            "/private/tmp/hmux-501.sock",
        ]

        for alias in aliases {
            let path = SocketControlSettings.socketPath(
                environment: [
                    "HMUX_SOCKET_PATH": alias,
                    "HMUX_ALLOW_SOCKET_OVERRIDE": "1",
                ],
                bundleIdentifier: "com.hmuxterm.app.debug.sockguard",
                isDebugBuild: false,
                currentUserID: 501
            )

            #expect(path == "/tmp/hmux-debug-sockguard.sock", "alias: \(alias)")
        }
    }

    @Test func taggedDebugBundleRefusesCanonicalLegacyStableSocketAliasEvenWithOptInFlag() {
        let path = SocketControlSettings.socketPath(
            environment: [
                "HMUX_SOCKET_PATH": "/private/tmp/hmux.sock",
                "HMUX_ALLOW_SOCKET_OVERRIDE": "1",
            ],
            bundleIdentifier: "com.hmuxterm.app.debug.sockguard",
            isDebugBuild: false
        )

        #expect(path == "/tmp/hmux-debug-sockguard.sock")
    }

    @Test func socketPathMatchingTreatsPrivateTmpLegacyStableAliasAsSamePath() {
        #expect(
            SocketControlSettings.pathsMatch(
                SocketControlSettings.legacyStableDefaultSocketPath,
                "/private/tmp/hmux.sock"
            )
        )
    }

    @Test func taggedDebugBundleRefusesCaseVariantStableSocketAliasesEvenWithOptInFlag() {
        let aliases = [
            "/tmp/HMUX.sock",
            "/private/tmp/HMUX.sock",
            SocketControlSettings.userScopedStableSocketPath(currentUserID: 501)
                .replacingOccurrences(of: "hmux-501.sock", with: "HMUX-501.sock"),
            SocketControlSettings.legacyUserScopedStableSocketPath(currentUserID: 501)
                .replacingOccurrences(of: "hmux-501.sock", with: "HMUX-501.sock"),
        ]

        for alias in aliases {
            let path = SocketControlSettings.socketPath(
                environment: [
                    "HMUX_SOCKET_PATH": alias,
                    "HMUX_ALLOW_SOCKET_OVERRIDE": "1",
                ],
                bundleIdentifier: "com.hmuxterm.app.debug.sockguard",
                isDebugBuild: false,
                currentUserID: 501
            )

            #expect(path == "/tmp/hmux-debug-sockguard.sock", "alias: \(alias)")
        }
    }

    @Test func taggedDebugBundleRefusesLeafSymlinkToStableSocketEvenWithOptInFlag() throws {
        let alias = "/tmp/hmux-stable-alias-\(UUID().uuidString).sock"
        try? FileManager.default.removeItem(atPath: alias)
        try FileManager.default.createSymbolicLink(
            atPath: alias,
            withDestinationPath: SocketControlSettings.stableDefaultSocketPath
        )
        defer { try? FileManager.default.removeItem(atPath: alias) }

        let path = SocketControlSettings.socketPath(
            environment: [
                "HMUX_SOCKET_PATH": alias,
                "HMUX_ALLOW_SOCKET_OVERRIDE": "1",
            ],
            bundleIdentifier: "com.hmuxterm.app.debug.sockguard",
            isDebugBuild: false
        )

        #expect(path == "/tmp/hmux-debug-sockguard.sock")
    }

    @Test func taggedDebugBundleRefusesExcessiveSymlinkChainEvenWithOptInFlag() throws {
        let root = "/tmp/hmux-stable-chain-\(UUID().uuidString)"
        let aliases = (0...64).map { "\(root)-\($0).sock" }
        for alias in aliases {
            try? FileManager.default.removeItem(atPath: alias)
        }
        defer {
            for alias in aliases {
                try? FileManager.default.removeItem(atPath: alias)
            }
        }

        try FileManager.default.createSymbolicLink(
            atPath: aliases[64],
            withDestinationPath: SocketControlSettings.stableDefaultSocketPath
        )
        for index in stride(from: 63, through: 0, by: -1) {
            try FileManager.default.createSymbolicLink(
                atPath: aliases[index],
                withDestinationPath: aliases[index + 1]
            )
        }

        let path = SocketControlSettings.socketPath(
            environment: [
                "HMUX_SOCKET_PATH": aliases[0],
                "HMUX_ALLOW_SOCKET_OVERRIDE": "1",
            ],
            bundleIdentifier: "com.hmuxterm.app.debug.sockguard",
            isDebugBuild: false
        )

        #expect(path == "/tmp/hmux-debug-sockguard.sock")
    }

    // MARK: - Default path per channel

    @Test func defaultSocketPathByChannel() {
        #expect(
            SocketControlSettings.defaultSocketPath(
                bundleIdentifier: "com.hmuxterm.app",
                isDebugBuild: false,
                probeStableDefaultPathEntry: { _ in .missing }
            ) == SocketControlSettings.stableDefaultSocketPath
        )
        #expect(
            SocketControlSettings.defaultSocketPath(
                bundleIdentifier: "com.hmuxterm.app.nightly",
                isDebugBuild: false,
                probeStableDefaultPathEntry: { _ in .missing }
            ) == "/tmp/hmux-nightly.sock"
        )
        #expect(
            SocketControlSettings.defaultSocketPath(
                bundleIdentifier: "com.hmuxterm.app.nightly.tag",
                isDebugBuild: false,
                probeStableDefaultPathEntry: { _ in .missing }
            ) == "/tmp/hmux-nightly-tag.sock"
        )
        #expect(
            SocketControlSettings.defaultSocketPath(
                bundleIdentifier: "com.hmuxterm.app.debug.tag",
                isDebugBuild: false,
                probeStableDefaultPathEntry: { _ in .missing }
            ) == "/tmp/hmux-debug-tag.sock"
        )
        #expect(
            SocketControlSettings.defaultSocketPath(
                bundleIdentifier: "com.hmuxterm.app.staging.tag",
                isDebugBuild: false,
                probeStableDefaultPathEntry: { _ in .missing }
            ) == "/tmp/hmux-staging-tag.sock"
        )
    }

    @Test func stableReleaseFallsBackToUserScopedSocketWhenStablePathOwnedByDifferentUser() {
        let path = SocketControlSettings.defaultSocketPath(
            bundleIdentifier: "com.hmuxterm.app",
            isDebugBuild: false,
            currentUserID: 501,
            probeStableDefaultPathEntry: { _ in .socket(ownerUserID: 0) }
        )

        #expect(path == SocketControlSettings.userScopedStableSocketPath(currentUserID: 501))
    }

    @Test func stableReleaseFallsBackToUserScopedSocketWhenStablePathIsBlockedByNonSocketEntry() {
        let path = SocketControlSettings.defaultSocketPath(
            bundleIdentifier: "com.hmuxterm.app",
            isDebugBuild: false,
            currentUserID: 501,
            probeStableDefaultPathEntry: { _ in .other(ownerUserID: 501) }
        )

        #expect(path == SocketControlSettings.userScopedStableSocketPath(currentUserID: 501))
    }

    // MARK: - Pre-listener startup path

    @Test func initialStableLaunchFallsBackToUserScopedSocketWhenSameUserStablePathIsLive() {
        let path = SocketControlSettings.initialSocketPathBeforeListenerStart(
            preferredPath: SocketControlSettings.stableDefaultSocketPath,
            bundleIdentifier: "com.hmuxterm.app",
            isDebugBuild: false,
            currentUserID: 501,
            probeStableDefaultPathEntry: { _ in .socket(ownerUserID: 501) },
            stableDefaultSocketCanBeReclaimed: { _ in false }
        )

        #expect(path == SocketControlSettings.userScopedStableSocketPath(currentUserID: 501))
    }

    @Test func initialStableLaunchTreatsPrivateTmpLegacyStableAliasAsStablePath() {
        var probedPath: String?
        let path = SocketControlSettings.initialSocketPathBeforeListenerStart(
            preferredPath: "/private/tmp/hmux.sock",
            bundleIdentifier: "com.hmuxterm.app",
            isDebugBuild: false,
            currentUserID: 501,
            probeStableDefaultPathEntry: { socketPath in
                probedPath = socketPath
                return .socket(ownerUserID: 501)
            },
            stableDefaultSocketCanBeReclaimed: { _ in false }
        )

        #expect(probedPath == "/private/tmp/hmux.sock")
        #expect(path == SocketControlSettings.userScopedStableSocketPath(currentUserID: 501))
    }

    @Test func initialStableLaunchUsesTransportReclaimabilityForSameUserSocket() {
        var didProbe = false
        let path = SocketControlSettings.initialSocketPathBeforeListenerStart(
            preferredPath: SocketControlSettings.stableDefaultSocketPath,
            bundleIdentifier: "com.hmuxterm.app",
            isDebugBuild: false,
            currentUserID: 501,
            probeStableDefaultPathEntry: { _ in .socket(ownerUserID: 501) },
            stableDefaultSocketCanBeReclaimed: { _ in
                didProbe = true
                return false
            }
        )

        #expect(didProbe)
        #expect(path == SocketControlSettings.userScopedStableSocketPath(currentUserID: 501))
    }

    @Test func initialStableLaunchKeepsStablePathWhenTransportReclaimsSameUserSocket() {
        var reclaimedPath: String?
        let path = SocketControlSettings.initialSocketPathBeforeListenerStart(
            preferredPath: SocketControlSettings.stableDefaultSocketPath,
            bundleIdentifier: "com.hmuxterm.app",
            isDebugBuild: false,
            currentUserID: 501,
            probeStableDefaultPathEntry: { _ in .socket(ownerUserID: 501) },
            stableDefaultSocketCanBeReclaimed: { socketPath in
                reclaimedPath = socketPath
                return true
            }
        )

        #expect(reclaimedPath == SocketControlSettings.stableDefaultSocketPath)
        #expect(path == SocketControlSettings.stableDefaultSocketPath)
    }

    @Test func initialStableLaunchKeepsUserScopedPreferredPathWithoutProbing() {
        let userScopedPath = SocketControlSettings.userScopedStableSocketPath(currentUserID: 501)
        var didInspect = false
        var didReclaim = false
        let path = SocketControlSettings.initialSocketPathBeforeListenerStart(
            preferredPath: userScopedPath,
            bundleIdentifier: "com.hmuxterm.app",
            isDebugBuild: false,
            currentUserID: 501,
            probeStableDefaultPathEntry: { _ in
                didInspect = true
                return .socket(ownerUserID: 501)
            },
            stableDefaultSocketCanBeReclaimed: { _ in
                didReclaim = true
                return false
            }
        )

        #expect(!didInspect, "User-scoped startup path must not be re-inspected")
        #expect(!didReclaim, "User-scoped startup path must not be reclaimed")
        #expect(path == userScopedPath)
    }

    @Test func initialStableLaunchFallsBackToUserScopedSocketWhenMissingStablePathCannotBeReserved() {
        var reclaimedPath: String?
        let path = SocketControlSettings.initialSocketPathBeforeListenerStart(
            preferredPath: SocketControlSettings.stableDefaultSocketPath,
            bundleIdentifier: "com.hmuxterm.app",
            isDebugBuild: false,
            currentUserID: 501,
            probeStableDefaultPathEntry: { _ in .missing },
            stableDefaultSocketCanBeReclaimed: { socketPath in
                reclaimedPath = socketPath
                return false
            }
        )

        #expect(reclaimedPath == SocketControlSettings.stableDefaultSocketPath)
        #expect(path == SocketControlSettings.userScopedStableSocketPath(currentUserID: 501))
    }

    @Test func initialSocketPathDoesNotProbeForTaggedDebugBuild() {
        let debugPath = "/tmp/hmux-debug-tag.sock"
        var didInspect = false
        let path = SocketControlSettings.initialSocketPathBeforeListenerStart(
            preferredPath: debugPath,
            bundleIdentifier: "com.hmuxterm.app.debug.tag",
            isDebugBuild: false,
            currentUserID: 501,
            probeStableDefaultPathEntry: { _ in
                didInspect = true
                return .socket(ownerUserID: 501)
            }
        )

        #expect(!didInspect, "Tagged debug builds must not inspect the stable socket")
        #expect(path == debugPath)
    }

    // MARK: - Untagged-debug launch gate

    @Test func untaggedDebugBundleAllowedWithLaunchTag() {
        #expect(
            !SocketControlSettings.shouldBlockUntaggedDebugLaunch(
                environment: ["HMUX_TAG": "tests-v1"],
                bundleIdentifier: "com.hmuxterm.app.debug",
                isDebugBuild: true
            )
        )
    }

    @Test func releaseBuildOfADebugBundleIgnoresLaunchTagGate() {
        #expect(
            !SocketControlSettings.shouldBlockUntaggedDebugLaunch(
                environment: [:],
                bundleIdentifier: "com.hmuxterm.app.debug",
                isDebugBuild: false
            )
        )
    }

    @Test(arguments: [
        ["XCTestConfigurationFilePath": "/tmp/fake.xctestconfiguration"],
        ["XCInjectBundle": "/tmp/fake.xctest"],
        ["DYLD_INSERT_LIBRARIES": "/usr/lib/libXCTestBundleInject.dylib"],
        // XCUITest launches the app as a separate process without XCTest env
        // vars; the app receives HMUX_UI_TEST_* via XCUIApplication.launchEnvironment.
        ["HMUX_UI_TEST_MODE": "1"],
    ])
    func testHarnessLaunchesIgnoreLaunchTagGate(environment: [String: String]) {
        #expect(
            !SocketControlSettings.shouldBlockUntaggedDebugLaunch(
                environment: environment,
                bundleIdentifier: "com.hmuxterm.app.debug",
                isDebugBuild: true
            )
        )
    }
}
