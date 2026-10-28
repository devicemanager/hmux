import Testing
import Foundation

#if canImport(hmux_DEV)
@testable import hmux_DEV
#elseif canImport(hmux)
@testable import hmux
#endif

private func canonicalAppHostPath(_ path: String) -> String {
    URL(fileURLWithPath: path)
        .resolvingSymlinksInPath()
        .standardizedFileURL
        .path
}

private func validateAppHostUserConfigurationHome(
    environment: [String: String],
    isolationRequired: Bool
) throws {
    guard isolationRequired else {
        return
    }

    #expect(environment["HMUX_APP_HOST_ISOLATION_REQUIRED"] == "1")
    let expectedHome = try #require(
        environment["HMUX_APP_HOST_EXPECTED_HOME"],
        "The isolated app-host launch must publish its resolved home"
    )
    let expectedXDGConfigHome = try #require(
        environment["HMUX_APP_HOST_EXPECTED_XDG_CONFIG_HOME"],
        "The isolated app-host launch must publish its resolved XDG config home"
    )

    #expect(environment["HOME"] == expectedHome)
    #expect(environment["CFFIXED_USER_HOME"] == expectedHome)
    #expect(environment["XDG_CONFIG_HOME"] == expectedXDGConfigHome)
    #expect(environment["SSH_AUTH_SOCK"] == "")
    #expect(
        canonicalAppHostPath(
            FileManager.default.homeDirectoryForCurrentUser.path
        ) == canonicalAppHostPath(expectedHome)
    )
    #expect(
        FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first.map { canonicalAppHostPath($0.path) }
            == canonicalAppHostPath(
                URL(fileURLWithPath: expectedHome, isDirectory: true)
                    .appendingPathComponent(
                        "Library/Application Support",
                        isDirectory: true
                    ).path
            )
    )
    #expect(
        canonicalAppHostPath(
            NSString(string: "~/Library/Application Support")
                .expandingTildeInPath
        ) == canonicalAppHostPath(
            URL(fileURLWithPath: expectedHome, isDirectory: true)
                .appendingPathComponent(
                    "Library/Application Support",
                    isDirectory: true
                ).path
        )
    )
}

private var appHostIsolationRequiredByBuild: Bool {
    #if HMUX_CI_APP_HOST_ISOLATION_REQUIRED
    true
    #else
    false
    #endif
}

@Suite struct MacSentryStartupPolicyTests {
    @Test func appHostUsesSchemeScopedUserConfigurationHome() throws {
        let environment = ProcessInfo.processInfo.environment
        try validateAppHostUserConfigurationHome(
            environment: environment,
            isolationRequired: appHostIsolationRequiredByBuild
                || environment["HMUX_APP_HOST_ISOLATION_REQUIRED"] == "1"
        )
    }

    @Test func appHostIsolationValidationIsOptIn() throws {
        try validateAppHostUserConfigurationHome(
            environment: [:],
            isolationRequired: false
        )
    }

    @Test func xctestLaunchDoesNotStartSentry() {
        #expect(
            MacSentryStartupPolicy(
                telemetryEnabled: true,
                isRunningUnderXCTest: true,
                allowUnderXCTest: false,
                allowsBuildIdentity: true
            ).shouldStart == false
        )
    }

    @Test func explicitTestTelemetryOptInStartsSentry() {
        #expect(
            MacSentryStartupPolicy(
                telemetryEnabled: true,
                isRunningUnderXCTest: true,
                allowUnderXCTest: true,
                allowsBuildIdentity: true
            ).shouldStart == true
        )
    }

    @Test func normalTelemetryEnabledLaunchStartsSentry() {
        #expect(
            MacSentryStartupPolicy(
                telemetryEnabled: true,
                isRunningUnderXCTest: false,
                allowUnderXCTest: false,
                allowsBuildIdentity: true
            ).shouldStart == true
        )
    }

    @Test func telemetryOptOutStillPreventsSentryStartup() {
        #expect(
            MacSentryStartupPolicy(
                telemetryEnabled: false,
                isRunningUnderXCTest: false,
                allowUnderXCTest: false,
                allowsBuildIdentity: true
            ).shouldStart == false
        )
    }

    @Test func explicitUITestMarkerPreventsSentryStartup() {
        #expect(
            MacSentryStartupPolicy(
                environment: ["HMUX_UI_TEST_PROCESS": "1"],
                telemetryEnabled: true
            ).shouldStart == false
        )
    }

    @Test func testRunnerMarkerPreventsSentryStartup() {
        #expect(
            MacSentryStartupPolicy(
                environment: ["HMUX_TEST_PROCESS": "1"],
                telemetryEnabled: true
            ).shouldStart == false
        )
    }

    @Test func explicitTestTelemetryOptInOverridesUITestMarker() {
        #expect(
            MacSentryStartupPolicy(
                environment: [
                    "HMUX_UI_TEST_PROCESS": "1",
                    "HMUX_TEST_SENTRY_ENABLED": "1"
                ],
                telemetryEnabled: true
            ).shouldStart == true
        )
    }

    @Test func foreignBundleIdentityPreventsSentryStartup() {
        // A rebranded public-repo fork keeping the hardcoded hmux DSN must
        // not start Sentry (Sentry issue HMUXTERM-MACOS-1RZF).
        #expect(
            MacSentryStartupPolicy(
                environment: [:],
                telemetryEnabled: true,
                bundleIdentifier: "mosaic.com.emergent.app"
            ).shouldStart == false
        )
    }

    @Test func missingBundleIdentityPreventsSentryStartup() {
        #expect(
            MacSentryStartupPolicy(
                environment: [:],
                telemetryEnabled: true,
                bundleIdentifier: nil
            ).shouldStart == false
        )
    }

    @Test(arguments: [
        "com.hmuxterm.app",
        "com.hmuxterm.app.nightly",
        "com.hmuxterm.app.rc",
        "com.hmuxterm.app.rc.candidate1",
        "com.hmuxterm.app.debug.snmsc"
    ])
    func hmuxBundleIdentityStartsSentry(_ bundleIdentifier: String) {
        #expect(
            MacSentryStartupPolicy(
                environment: [:],
                telemetryEnabled: true,
                bundleIdentifier: bundleIdentifier
            ).shouldStart == true
        )
    }
}
