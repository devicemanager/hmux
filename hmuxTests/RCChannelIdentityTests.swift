import HmuxSettings
import HmuxUpdater
import Foundation
import XCTest

#if canImport(hmux_DEV)
@testable import hmux_DEV
#elseif canImport(hmux)
@testable import hmux
#endif

/// The `rc` release channel (`com.hmuxterm.app.rc`, "hmux RC.app") is a fourth
/// lane next to stable, nightly, and staging. These tests pin the identity
/// surfaces that key off the channel: build flavor, socket path, icon
/// persistence, and the update feed.
final class RCChannelIdentityTests: XCTestCase {
    @MainActor
    func testBundleIconPersistenceSkipsRCBundles() {
        XCTAssertFalse(
            AppBundleIconPersistencePolicy.shouldPersist(
                bundleIdentifier: "com.hmuxterm.app.rc",
                appBundleLastPathComponent: "hmux RC.app",
                persistenceDisabled: false
            )
        )
        XCTAssertFalse(
            AppBundleIconPersistencePolicy.shouldPersist(
                bundleIdentifier: "com.hmuxterm.app.rc.candidate1",
                appBundleLastPathComponent: "hmux RC candidate1.app",
                persistenceDisabled: false
            )
        )
    }

    func testRCReleaseUsesDedicatedDefaultAndIgnoresAmbientSocketOverride() {
        let path = SocketControlSettings.socketPath(
            environment: [
                "HMUX_SOCKET_PATH": "/tmp/hmux-debug-issue-153-tmux-compat.sock",
            ],
            bundleIdentifier: "com.hmuxterm.app.rc",
            isDebugBuild: false,
            probeStableDefaultPathEntry: { _ in .missing }
        )

        XCTAssertEqual(path, "/tmp/hmux-rc.sock")
    }

    func testDefaultSocketPathForRCBundles() {
        XCTAssertEqual(
            SocketControlSettings.defaultSocketPath(
                bundleIdentifier: "com.hmuxterm.app.rc",
                isDebugBuild: false,
                probeStableDefaultPathEntry: { _ in .missing }
            ),
            "/tmp/hmux-rc.sock"
        )
        XCTAssertEqual(
            SocketControlSettings.defaultSocketPath(
                bundleIdentifier: "com.hmuxterm.app.rc.tag",
                isDebugBuild: false,
                probeStableDefaultPathEntry: { _ in .missing }
            ),
            "/tmp/hmux-rc-tag.sock"
        )
    }

    func testDetectsRCFromBundleIdentifier() {
        XCTAssertEqual(
            BuildFlavor.detect(bundleName: "hmux", bundleIdentifier: "com.hmuxterm.app.rc"),
            .rc
        )
        XCTAssertEqual(
            BuildFlavor.detect(bundleName: "hmux", bundleIdentifier: "com.hmuxterm.app.rc.candidate1"),
            .rc
        )
    }

    func testDetectsRCFromBundleName() {
        XCTAssertEqual(
            BuildFlavor.detect(bundleName: "hmux RC", bundleIdentifier: "com.hmuxterm.app"),
            .rc
        )
    }

    func testResolvedFeedDetectsRCFromInfoFeedURL() {
        let resolved = UpdateFeedResolver(hostArchitecture: .arm64).resolve(
            infoFeedURL: "https://files.cmux.com/rc/appcast.xml"
        )
        XCTAssertEqual(resolved.url, "https://files.cmux.com/rc/appcast-arm64.xml")
        XCTAssertEqual(resolved.channel, .rc)
        XCTAssertFalse(resolved.isNightly)
        XCTAssertFalse(resolved.usedFallback)
    }
}

extension GhosttyConfigPathResolverTests {
    func testHmuxAppSupportConfigURLsUseReleaseConfigForRCWithoutCurrentConfig() throws {
        try withTemporaryAppSupportDirectory { appSupportDirectory in
            let releaseConfigURL = try writeAppSupportConfig(
                appSupportDirectory: appSupportDirectory,
                bundleIdentifier: "com.hmuxterm.app",
                filename: "config.ghostty",
                contents: "font-size = 13\n"
            )

            XCTAssertEqual(
                GhosttyApp.hmuxAppSupportConfigURLs(
                    currentBundleIdentifier: "com.hmuxterm.app.rc",
                    appSupportDirectory: appSupportDirectory
                ),
                [releaseConfigURL]
            )
        }
    }

    func testHmuxAppSupportConfigURLsUseRCConfigWhenPresent() throws {
        try withTemporaryAppSupportDirectory { appSupportDirectory in
            _ = try writeAppSupportConfig(
                appSupportDirectory: appSupportDirectory,
                bundleIdentifier: "com.hmuxterm.app",
                filename: "config.ghostty",
                contents: "font-size = 13\n"
            )
            let rcConfigURL = try writeAppSupportConfig(
                appSupportDirectory: appSupportDirectory,
                bundleIdentifier: "com.hmuxterm.app.rc",
                filename: "config.ghostty",
                contents: "font-size = 15\n"
            )

            XCTAssertEqual(
                GhosttyApp.hmuxAppSupportConfigURLs(
                    currentBundleIdentifier: "com.hmuxterm.app.rc",
                    appSupportDirectory: appSupportDirectory
                ),
                [rcConfigURL]
            )
        }
    }
}
