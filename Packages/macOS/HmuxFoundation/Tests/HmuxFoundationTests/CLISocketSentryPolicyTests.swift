import Testing
@testable import HmuxFoundation

@Suite struct CLISocketSentryPolicyTests {
    @Test(arguments: ["seatbelt", "read-only", "workspace-write"])
    func recognizesRestrictedCodexSandbox(_ value: String) {
        #expect(CLISocketSentryPolicy(
            environment: ["CODEX_SANDBOX": value]
        ).allowsSandboxPolicyDenial)
    }

    @Test(arguments: ["danger-full-access", "disabled", "none", "off", "unrestricted", "future-mode", " "])
    func keepsPolicyDenialsFromUnrestrictedOrMissingSandbox(_ value: String) {
        #expect(!CLISocketSentryPolicy(
            environment: ["CODEX_SANDBOX": value]
        ).allowsSandboxPolicyDenial)
    }

    @Test func doesNotInferSandboxFromAgentIdentity() {
        #expect(!CLISocketSentryPolicy(
            environment: [
                "CODEX_CI": "1",
                "HMUX_AGENT_LAUNCH_KIND": "codex"
            ]
        ).allowsSandboxPolicyDenial)
    }
}
