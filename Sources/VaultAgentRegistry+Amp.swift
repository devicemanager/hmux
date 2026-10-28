import HMUXAgentLaunch
import Foundation

extension HmuxVaultAgentRegistration {
    /// Amp's built-in Vault registration backed by hmux's managed hook store.
    static var builtInAmp: HmuxVaultAgentRegistration {
        HmuxVaultAgentRegistration(
            id: "amp",
            name: "Amp",
            iconAssetName: "AgentIcons/Amp",
            detect: HmuxVaultAgentDetectRule(processName: "amp"),
            sessionIdSource: .hmuxHookStore(.amp),
            resumeCommand: RegisteredAgentResumeKind.amp.commandTemplate,
            cwd: .preserve
        )
    }
}
