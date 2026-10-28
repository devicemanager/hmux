import HMUXAgentLaunch
import Foundation

extension HmuxVaultAgentRegistration {
    static var builtInHermes: HmuxVaultAgentRegistration {
        HmuxVaultAgentRegistration(
            id: "hermes-agent",
            name: String(
                localized: "sessionIndex.agent.hermesAgent",
                defaultValue: "Hermes Agent"
            ),
            iconAssetName: "AgentIcons/HermesAgent",
            detect: HmuxVaultAgentDetectRule(
                processNames: ["hermes", "hermes-agent"],
                alternateProcessNames: ["python", "python3"],
                alternateArgvBasenamesAny: ["hermes", "hermes-agent"]
            ),
            sessionIdSource: .persistedStore(.hermesStateDB),
            resumeCommand: "{{executable}} --resume {{sessionId}}",
            cwd: .preserve
        )
    }

    /// The persisted-session semantics supported by this exact hmux-owned registration.
    ///
    /// Keeping this separate from the decoded `sessionIdSource` prevents a custom Vault
    /// registration from claiming the built-in Hermes argument and indexing contract.
    var persistedSessionStoreCapability: HmuxVaultAgentPersistedSessionStore? {
        self == Self.builtInHermes ? .hermesStateDB : nil
    }
}
