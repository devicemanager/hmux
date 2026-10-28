import HMUXAgentLaunch
import Testing

@Suite("CodexForkMonitorArguments")
struct CodexForkMonitorArgumentsTests {
    private let builder = CodexForkMonitorArguments()

    @Test("forwards fork ownership values")
    func forwardsOwnershipValues() {
        #expect(builder.make(environment: [
            "HMUX_AGENT_FORK_PARENT_SESSION_ID": "parent-session",
            "HMUX_AGENT_FORK_LAUNCH_ID": "launch-id",
            "HMUX_CODEX_PID": "1234",
        ]) == [
            "--fork-parent", "parent-session",
            "--fork-launch-id", "launch-id",
            "--fork-owner-pid", "1234",
        ])
    }

    @Test("omits optional values when absent")
    func omitsOptionalValuesWhenAbsent() {
        #expect(builder.make(environment: [
            "HMUX_AGENT_FORK_PARENT_SESSION_ID": "parent-session",
        ]) == ["--fork-parent", "parent-session"])
        #expect(builder.make(environment: [:]).isEmpty)
    }
}
