import HMUXAgentLaunch
import Testing

@Suite("CLIForwardingDecision")
struct CLIForwardingDecisionTests {
    /// A CLI invocation that reaches the GUI binary with the forwarding
    /// guard already set must not fall through to a GUI launch: hook
    /// commands (`hmux claude-hook …`) would each leave a faceless app
    /// instance running forever.
    @Test("CLI argv with the guard set fails closed")
    func cliArgvWithGuardSetFailsClosed() {
        #expect(
            CLIForwardingDecision(
                arguments: ["hmux", "claude-hook", "pre-tool-use"],
                forwardingGuardIsSet: true
            ) == .failForwardingLoop
        )
        #expect(
            CLIForwardingDecision(
                arguments: ["hmux", "claude-hook", "pre-tool-use"],
                forwardingGuardIsSet: false
            ) == .forwardToBundledCLI
        )
    }

    /// GUI-style launches (no subcommand, `-psn_...` flags, `hmux://` URLs,
    /// launch sentinels) stay in the app regardless of the forwarding guard.
    @Test("GUI argv launches the app even with the guard set")
    func guiArgvLaunchesAppEvenWithGuardSet() {
        #expect(
            CLIForwardingDecision(arguments: ["hmux"], forwardingGuardIsSet: true) == .launchGUI
        )
        #expect(
            CLIForwardingDecision(
                arguments: ["hmux", "-psn_0_12345"],
                forwardingGuardIsSet: true
            ) == .launchGUI
        )
        #expect(
            CLIForwardingDecision(
                arguments: ["hmux", "hmux://workspace/foo"],
                forwardingGuardIsSet: true
            ) == .launchGUI
        )
        #expect(
            CLIForwardingDecision(
                arguments: ["hmux DEV", "DEV"],
                forwardingGuardIsSet: true
            ) == .launchGUI
        )
        #expect(
            CLIForwardingDecision(
                arguments: ["hmux RC", "RC"],
                forwardingGuardIsSet: true
            ) == .launchGUI
        )
    }

    /// CLI-style subcommands forward to the bundled CLI on the first pass.
    @Test("CLI subcommands forward to the bundled CLI")
    func cliSubcommandsForward() {
        #expect(CLIForwardingDecision.shouldForwardToBundledCLI(arguments: ["hmux", "wait-for", "workspace:1"]))
        #expect(CLIForwardingDecision.shouldForwardToBundledCLI(arguments: ["hmux", "hooks", "setup"]))
        #expect(!CLIForwardingDecision.shouldForwardToBundledCLI(arguments: ["hmux", "-psn_0_12345"]))
        #expect(!CLIForwardingDecision.shouldForwardToBundledCLI(arguments: ["hmux", "hmux://workspace/foo"]))
    }
}
