import Foundation
import Testing
import HMUXAgentLaunch

#if canImport(hmux_DEV)
@testable import hmux_DEV
#elseif canImport(hmux)
@testable import hmux
#endif

struct CodexForkMonitorArgumentTests {
    @Test
    func forwardsForkParentClaimToDetachedMonitor() {
        let arguments = CodexForkMonitorArguments().make(environment: [
            "HMUX_AGENT_FORK_PARENT_SESSION_ID": "parent-session",
            "HMUX_AGENT_FORK_LAUNCH_ID": "launch-id",
            "HMUX_CODEX_PID": "1234",
        ])

        #expect(arguments == [
            "--fork-parent", "parent-session",
            "--fork-launch-id", "launch-id",
            "--fork-owner-pid", "1234",
        ])
    }

    @Test
    func omitsForkArgumentsForNormalCodexMonitor() {
        #expect(CodexForkMonitorArguments().make(environment: [:]).isEmpty)
    }
    @Test
    func omitsForkArgumentsWithoutValidParent() {
        for parent in [String?.none, ""] {
            var environment = ["HMUX_AGENT_FORK_LAUNCH_ID": "launch-id", "HMUX_CODEX_PID": "1234"]
            environment["HMUX_AGENT_FORK_PARENT_SESSION_ID"] = parent
            #expect(HmuxTuiRemoteRouting.codexForkMonitorArguments(environment: environment).isEmpty)
        }
    }

    @Test
    func omitsEmptyOptionalForkMetadata() {
        #expect(HmuxTuiRemoteRouting.codexForkMonitorArguments(environment: [
            "HMUX_AGENT_FORK_PARENT_SESSION_ID": "parent-session",
            "HMUX_AGENT_FORK_LAUNCH_ID": "",
            "HMUX_CODEX_PID": "",
        ]) == ["--fork-parent", "parent-session"])
    }

}
