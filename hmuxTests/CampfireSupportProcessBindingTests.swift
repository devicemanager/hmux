import Foundation
import Testing

#if canImport(hmux_DEV)
@testable import hmux_DEV
#elseif canImport(hmux)
@testable import hmux
#endif

extension CampfireSupportTests {
    @Test func directProcessDetectionDoesNotTreatPlainCampfireArgumentAsAgent() throws {
        let root = try Self.makeTemporaryDirectory(prefix: "hmux-campfire-plain-argument-")
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = root.appendingPathComponent("repo", isDirectory: true)
        let sessionsRoot = root.appendingPathComponent("sessions", isDirectory: true)
        let projectDirectory = try #require(PiSessionLocator.projectDirectoryName(for: workspace.path))
        let projectSessions = sessionsRoot.appendingPathComponent(projectDirectory, isDirectory: true)
        try FileManager.default.createDirectory(at: projectSessions, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        _ = try Self.writeSessionFile(
            id: "campfire-should-not-bind",
            in: projectSessions,
            modifiedAt: Date(timeIntervalSince1970: 2_000)
        )

        let detected = Self.detectedCampfireSnapshot(
            processName: "rg",
            processPath: "/usr/bin/rg",
            arguments: ["/usr/bin/rg", "campfire"],
            environment: [
                "PWD": workspace.path,
                "CAMPFIRE_CODING_AGENT_SESSION_DIR": sessionsRoot.path,
            ]
        )

        #expect(detected == nil)
    }

    @Test func directProcessDetectionDoesNotTreatUnrelatedPackagesSessionArgumentAsAgent() throws {
        let root = try Self.makeTemporaryDirectory(prefix: "hmux-campfire-packages-session-argument-")
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = root.appendingPathComponent("repo", isDirectory: true)
        let sessionsRoot = root.appendingPathComponent("sessions", isDirectory: true)
        let projectDirectory = try #require(PiSessionLocator.projectDirectoryName(for: workspace.path))
        let projectSessions = sessionsRoot.appendingPathComponent(projectDirectory, isDirectory: true)
        try FileManager.default.createDirectory(at: projectSessions, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        _ = try Self.writeSessionFile(
            id: "campfire-should-not-bind-packages-session",
            in: projectSessions,
            modifiedAt: Date(timeIntervalSince1970: 2_000)
        )

        let detected = Self.detectedCampfireSnapshot(
            processName: "bun",
            processPath: "/opt/homebrew/bin/bun",
            arguments: [
                "/opt/homebrew/bin/bun",
                "/Users/example/campfire/packages/session/scripts/seed.ts",
            ],
            environment: [
                "PWD": workspace.path,
                "CAMPFIRE_CODING_AGENT_SESSION_DIR": sessionsRoot.path,
            ]
        )

        #expect(detected == nil)
    }

    @Test func directProcessDetectionDoesNotTreatMentionedCampfireEntrypointAsAgent() throws {
        let root = try Self.makeTemporaryDirectory(prefix: "hmux-campfire-mentioned-entrypoint-")
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = root.appendingPathComponent("repo", isDirectory: true)
        let sessionsRoot = root.appendingPathComponent("sessions", isDirectory: true)
        let projectDirectory = try #require(PiSessionLocator.projectDirectoryName(for: workspace.path))
        let projectSessions = sessionsRoot.appendingPathComponent(projectDirectory, isDirectory: true)
        try FileManager.default.createDirectory(at: projectSessions, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        _ = try Self.writeSessionFile(
            id: "campfire-should-not-bind-mentioned-entrypoint",
            in: projectSessions,
            modifiedAt: Date(timeIntervalSince1970: 2_000)
        )

        let detected = Self.detectedCampfireSnapshot(
            processName: "rg",
            processPath: "/usr/bin/rg",
            arguments: [
                "/usr/bin/rg",
                "packages/session/bin/campfire.ts",
            ],
            environment: [
                "PWD": workspace.path,
                "CAMPFIRE_CODING_AGENT_SESSION_DIR": sessionsRoot.path,
            ]
        )

        #expect(detected == nil)
    }

    @Test func directProcessDetectionSkipsNonHostCampfireRoles() throws {
        let root = try Self.makeTemporaryDirectory(prefix: "hmux-campfire-joiner-role-")
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = root.appendingPathComponent("repo", isDirectory: true)
        let sessionsRoot = root.appendingPathComponent("sessions", isDirectory: true)
        let projectDirectory = try #require(PiSessionLocator.projectDirectoryName(for: workspace.path))
        let projectSessions = sessionsRoot.appendingPathComponent(projectDirectory, isDirectory: true)
        try FileManager.default.createDirectory(at: projectSessions, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        _ = try Self.writeSessionFile(
            id: "campfire-should-not-bind-joiner",
            in: projectSessions,
            modifiedAt: Date(timeIntervalSince1970: 2_000)
        )

        for role in [nil, "joiner"] as [String?] {
            var environment = [
                "PWD": workspace.path,
                "CAMPFIRE_CODING_AGENT_SESSION_DIR": sessionsRoot.path,
            ]
            if let role {
                environment["CAMPFIRE_SESSION_ROLE"] = role
            }

            let detected = Self.detectedCampfireSnapshot(
                processName: "campfire",
                processPath: "/Users/example/.local/bin/campfire",
                arguments: [
                    "/Users/example/.local/bin/campfire",
                    "--join",
                    "https://campfire.example/invite/token",
                ],
                environment: environment,
                defaultCampfireSessionRole: nil
            )

            #expect(detected == nil, "role \(role ?? "<missing>") must not produce a restorable Campfire snapshot")
        }
    }

    @Test func taskManagerClassifiesCampfireCompiledBinaryAndDevInvocation() throws {
        let compiled = try #require(HmuxTaskManagerCodingAgentDefinition.matchingDefinition(
            processName: "campfire",
            processPath: "/Users/example/.local/bin/campfire",
            arguments: ["/Users/example/.local/bin/campfire", "--relay", "wss://relay.example/ws"],
            environment: [:]
        ))
        #expect(compiled.id == "campfire")

        let dev = try #require(HmuxTaskManagerCodingAgentDefinition.matchingDefinition(
            processName: "bun",
            processPath: "/opt/homebrew/bin/bun",
            arguments: [
                "/opt/homebrew/bin/bun",
                "/Users/example/campfire/packages/session/bin/campfire.ts",
            ],
            environment: [:]
        ))
        #expect(dev.id == "campfire")
    }

    @Test func builtInCampfireRegistrationResumesWithBareSessionId() throws {
        let registration = HmuxVaultAgentRegistration.builtInCampfire
        #expect(registration.id == "campfire")
        #expect(registration.resumeCommand == "{{executable}} --session {{sessionId}}")
        #expect(registration.sessionIdSource == .argvOption("--session"))
        #expect(registration.sessionDirectory == "~/.campfire/agent/sessions")
    }

    @Test func alternateOnlyDetectRuleDoesNotMatchUnrelatedProcess() throws {
        // A detect rule that specifies only alternate criteria (no primary
        // process names and no `argvContains`) must not classify an unrelated
        // process. Otherwise the empty primary criteria make the primary match
        // succeed for every process before the alternate criteria are checked.
        var registration = HmuxVaultAgentRegistration.builtInCampfire
        registration.detect = HmuxVaultAgentDetectRule(
            alternateArgvContainsAny: ["packages/session/bin/campfire.ts"]
        )

        let detected = Self.detectedCampfireSnapshot(
            processName: "node",
            processPath: "/opt/homebrew/bin/node",
            arguments: ["/opt/homebrew/bin/node", "some-other-script.js"],
            environment: ["PWD": "/tmp"],
            registration: registration
        )

        #expect(detected == nil)
    }

    @Test func alternateOnlyDetectRuleUsesDefaultExecutableForRestore() throws {
        var registration = HmuxVaultAgentRegistration.builtInCampfire
        registration.detect = HmuxVaultAgentDetectRule(
            alternateArgvContainsAny: ["packages/session/bin/campfire.ts"]
        )

        let detected = try #require(Self.detectedCampfireSnapshot(
            processName: "node",
            processPath: "/opt/homebrew/bin/node",
            arguments: [
                "/opt/homebrew/bin/node",
                "/Users/example/campfire/packages/session/bin/campfire.ts",
                "--session",
                "campfire-alternate-only-session",
                "--relay",
                "wss://relay.example/ws",
            ],
            environment: [
                "PWD": "/tmp/repo",
            ],
            registration: registration
        ))

        #expect(detected.sessionId == "campfire-alternate-only-session")
        #expect(detected.launchCommand?.executablePath == "campfire")
        #expect(detected.launchCommand?.arguments == [
            "campfire",
            "--session",
            "campfire-alternate-only-session",
            "--relay",
            "wss://relay.example/ws",
        ])
        #expect(detected.resumeCommand?.contains("'campfire' '--session'") == true)
        #expect(detected.resumeCommand?.contains("/opt/homebrew/bin/node") == false)
    }

    @Test func cachedValidatorUsesSameAlternateDetectRuleSemanticsAsProcessScanner() throws {
        var registration = HmuxVaultAgentRegistration.builtInCampfire
        registration.detect = HmuxVaultAgentDetectRule(
            processName: "campfire",
            alternateProcessNames: ["bun"],
            alternateArgvContainsAny: [
                "packages/session/bin/campfire.ts",
                "packages/session/dist/campfire",
            ]
        )
        let snapshot = SessionRestorableAgentSnapshot(
            kind: .custom("campfire"),
            sessionId: "campfire-validator-session",
            workingDirectory: nil,
            launchCommand: AgentLaunchCommandSnapshot(
                launcher: "campfire",
                executablePath: "campfire",
                arguments: ["campfire", "--session", "campfire-validator-session"],
                workingDirectory: nil,
                environment: nil,
                capturedAt: nil,
                source: "process"
            ),
            registration: registration
        )
        let matchingAlternate = HmuxTopProcessArguments(
            arguments: [
                "/opt/homebrew/bin/bun",
                "/Users/example/campfire/packages/session/dist/campfire",
                "--session",
                "campfire-validator-session",
            ],
            environment: [:]
        )
        let wrongAlternateHost = HmuxTopProcessArguments(
            arguments: [
                "/opt/homebrew/bin/node",
                "/Users/example/campfire/packages/session/dist/campfire",
                "--session",
                "campfire-validator-session",
            ],
            environment: [:]
        )

        let validator = CachedAgentProcessIdentityValidator()
        #expect(validator.currentProcess(matchingAlternate, matches: snapshot))
        #expect(validator.currentProcess(wrongAlternateHost, matches: snapshot) == false)
    }

    @Test func processDetectedCampfireDoesNotInferLatestSessionFile() throws {
        let root = try Self.makeTemporaryDirectory(prefix: "hmux-campfire-no-latest-fallback-")
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = root.appendingPathComponent("repo", isDirectory: true)
        let sessionsRoot = root.appendingPathComponent("sessions", isDirectory: true)
        let projectDirectory = try #require(PiSessionLocator.projectDirectoryName(for: workspace.path))
        let projectSessions = sessionsRoot.appendingPathComponent(projectDirectory, isDirectory: true)
        try FileManager.default.createDirectory(at: projectSessions, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        _ = try Self.writeSessionFile(
            id: "unrelated-newer-campfire-session",
            in: projectSessions,
            modifiedAt: Date(timeIntervalSince1970: 2_000)
        )

        let detected = Self.detectedCampfireSnapshot(
            processName: "campfire",
            processPath: "/Users/example/.local/bin/campfire",
            arguments: ["/Users/example/.local/bin/campfire"],
            environment: [
                "PWD": workspace.path,
                "CAMPFIRE_CODING_AGENT_SESSION_DIR": sessionsRoot.path,
            ]
        )

        #expect(detected == nil)
    }
}
