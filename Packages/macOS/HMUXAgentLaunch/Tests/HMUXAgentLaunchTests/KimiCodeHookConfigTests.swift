import HMUXAgentLaunch
import Testing

@Suite("KimiCodeHookConfig")
struct KimiCodeHookConfigTests {
    @Test("Installs hooks into empty config")
    func installsHooksIntoEmptyConfig() {
        let events = [
            KimiCodeHookConfig.Event(
                name: "SessionStart",
                command: "hmux hooks kimi session-start",
                timeout: 10
            ),
            KimiCodeHookConfig.Event(
                name: "PreToolUse",
                command: "hmux hooks feed --source kimi --event PreToolUse",
                timeout: 120
            ),
        ]

        let installed = KimiCodeHookConfig.installing(events: events, in: "")

        #expect(installed == """
        # hmux-kimi-hooks-7c3a9f12-4e8b-4d2a-9f15-6b8c0d1e2a3f begin
        [[hooks]]
        event = "SessionStart"
        command = "hmux hooks kimi session-start"
        timeout = 10

        [[hooks]]
        event = "PreToolUse"
        command = "hmux hooks feed --source kimi --event PreToolUse"
        timeout = 120

        # hmux-kimi-hooks-7c3a9f12-4e8b-4d2a-9f15-6b8c0d1e2a3f end

        """)
    }

    @Test("Install preserves existing user content with separating blank line")
    func installPreservesExistingUserContentWithSeparatingBlankLine() {
        let existing = """
        model = "kimi-k2"
        telemetry = false

        """
        let events = [
            KimiCodeHookConfig.Event(name: "Stop", command: "hmux hooks kimi stop", timeout: 10),
        ]

        let installed = KimiCodeHookConfig.installing(events: events, in: existing)

        #expect(installed == """
        model = "kimi-k2"
        telemetry = false

        # hmux-kimi-hooks-7c3a9f12-4e8b-4d2a-9f15-6b8c0d1e2a3f begin
        [[hooks]]
        event = "Stop"
        command = "hmux hooks kimi stop"
        timeout = 10

        # hmux-kimi-hooks-7c3a9f12-4e8b-4d2a-9f15-6b8c0d1e2a3f end

        """)
    }

    @Test("Install is idempotent")
    func installIsIdempotent() {
        let existing = "model = \"kimi-k2\"\n"
        let events = [
            KimiCodeHookConfig.Event(name: "Stop", command: "hmux hooks kimi stop", timeout: 10),
        ]

        let installed = KimiCodeHookConfig.installing(events: events, in: existing)

        #expect(KimiCodeHookConfig.installing(events: events, in: installed) == installed)
    }

    @Test("Reinstall replaces stale hmux block")
    func reinstallReplacesStaleHmuxBlock() {
        let stale = KimiCodeHookConfig.installing(
            events: [KimiCodeHookConfig.Event(name: "Stop", command: "hmux hooks kimi stop", timeout: 10)],
            in: "model = \"kimi-k2\"\n"
        )

        let reinstalled = KimiCodeHookConfig.installing(
            events: [KimiCodeHookConfig.Event(name: "Stop", command: "hmux hooks kimi stop", timeout: 20)],
            in: stale
        )

        #expect(reinstalled.components(separatedBy: "# hmux-kimi-hooks-7c3a9f12-4e8b-4d2a-9f15-6b8c0d1e2a3f begin").count == 2)
        #expect(reinstalled.contains("timeout = 20"))
        #expect(!reinstalled.contains("timeout = 10"))
    }

    @Test("Install uninstall round trip restores normalized existing content")
    func installUninstallRoundTripRestoresNormalizedExistingContent() {
        let existing = "model = \"kimi-k2\"\ntelemetry = false\n\n"
        let events = [
            KimiCodeHookConfig.Event(name: "Stop", command: "hmux hooks kimi stop", timeout: 10),
        ]

        let installed = KimiCodeHookConfig.installing(events: events, in: existing)

        #expect(KimiCodeHookConfig.uninstalling(from: installed) == existing)
    }

    @Test("Uninstall without hmux block leaves content unchanged")
    func uninstallWithoutHmuxBlockLeavesContentUnchanged() {
        let existing = """
        model = "kimi-k2"
        telemetry = false

        """

        #expect(KimiCodeHookConfig.uninstalling(from: existing) == existing)
    }

    @Test("Detects whether a config carries a hmux block")
    func detectsWhetherConfigCarriesHmuxBlock() {
        let userOnly = """
        model = "kimi-k2"

        [[hooks]]
        event = "Stop"
        command = "vibe-island"

        """
        let installed = KimiCodeHookConfig.installing(
            events: [
                KimiCodeHookConfig.Event(
                    name: "Stop",
                    command: "hmux hooks kimi stop",
                    timeout: 10
                ),
            ],
            in: userOnly
        )

        #expect(!KimiCodeHookConfig.containsHmuxBlock(in: ""))
        #expect(!KimiCodeHookConfig.containsHmuxBlock(in: userOnly))
        #expect(KimiCodeHookConfig.containsHmuxBlock(in: installed))
        #expect(!KimiCodeHookConfig.containsHmuxBlock(
            in: KimiCodeHookConfig.uninstalling(from: installed)
        ))
    }

    @Test("Uninstall removes orphaned begin marker without dropping following TOML")
    func uninstallRemovesOrphanedBeginMarkerWithoutDroppingFollowingTOML() {
        let existing = """
        model = "kimi-k2"
        # hmux-kimi-hooks-7c3a9f12-4e8b-4d2a-9f15-6b8c0d1e2a3f begin
        telemetry = false

        """

        #expect(KimiCodeHookConfig.uninstalling(from: existing) == """
        model = "kimi-k2"
        telemetry = false

        """)
    }

    @Test("Uninstall removes consecutive orphaned begin markers without dropping following TOML")
    func uninstallRemovesConsecutiveOrphanedBeginMarkersWithoutDroppingFollowingTOML() {
        let existing = """
        # hmux-kimi-hooks-7c3a9f12-4e8b-4d2a-9f15-6b8c0d1e2a3f begin
        # hmux-kimi-hooks-7c3a9f12-4e8b-4d2a-9f15-6b8c0d1e2a3f begin
        model = "kimi-k2"

        """

        #expect(KimiCodeHookConfig.uninstalling(from: existing) == """
        model = "kimi-k2"

        """)
    }

    @Test("Detects, refreshes, and removes a hmux block written with CRLF line endings")
    func handlesCRLFLineEndings() {
        let eventsV1 = [
            KimiCodeHookConfig.Event(name: "Stop", command: "hmux hooks kimi stop", timeout: 10),
        ]
        let crlfExisting = "model = \"kimi-k2\"\r\ntelemetry = false\r\n"

        // Isolates the line-count half of the bug, independent of marker
        // matching: normalizing CRLF content with no hmux block at all must
        // not gain a trailing blank line. `content.hasSuffix("\n")` is false
        // for CRLF-terminated content (Swift treats "\r\n" as one Character),
        // so the naive fix leaves the split's trailing empty element in place.
        #expect(
            KimiCodeHookConfig.uninstalling(from: crlfExisting)
                == "model = \"kimi-k2\"\ntelemetry = false\n"
        )

        let installed = KimiCodeHookConfig.installing(events: eventsV1, in: crlfExisting)
        #expect(KimiCodeHookConfig.containsHmuxBlock(in: installed))

        // Reconstruct the installed config with CRLF endings, as a CRLF-editing
        // tool would leave it, and confirm a refresh still finds and replaces
        // the existing block instead of appending a second one.
        let crlfInstalled = installed.replacingOccurrences(of: "\n", with: "\r\n")
        #expect(KimiCodeHookConfig.containsHmuxBlock(in: crlfInstalled))

        let eventsV2 = [
            KimiCodeHookConfig.Event(name: "Stop", command: "hmux hooks kimi stop", timeout: 20),
        ]
        let refreshed = KimiCodeHookConfig.installing(events: eventsV2, in: crlfInstalled)
        #expect(refreshed.components(separatedBy: "# hmux-kimi-hooks-7c3a9f12-4e8b-4d2a-9f15-6b8c0d1e2a3f begin").count == 2)
        #expect(refreshed.contains("timeout = 20"))
        #expect(!refreshed.contains("timeout = 10"))

        // Round-tripping through CRLF must land on the same normalized (LF)
        // content as the plain-LF path — CR handling must not add or drop a line.
        #expect(
            KimiCodeHookConfig.uninstalling(from: crlfInstalled)
                == KimiCodeHookConfig.uninstalling(from: installed)
        )
        #expect(KimiCodeHookConfig.uninstalling(from: crlfInstalled) == "model = \"kimi-k2\"\ntelemetry = false\n\n")
    }

    @Test("Escapes TOML basic string content")
    func escapesTOMLBasicStringContent() {
        let events = [
            KimiCodeHookConfig.Event(
                name: "PermissionRequest",
                command: "hmux hooks \"kimi\" \\\tpermission",
                timeout: 10
            ),
        ]

        let installed = KimiCodeHookConfig.installing(events: events, in: "")

        #expect(installed.contains(#"command = "hmux hooks \"kimi\" \\\tpermission""#))
    }
}
