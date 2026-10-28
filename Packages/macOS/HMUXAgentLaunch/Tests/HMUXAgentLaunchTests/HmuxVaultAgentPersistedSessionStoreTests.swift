import HMUXAgentLaunch
import Testing

@Suite("HmuxVaultAgentPersistedSessionStore")
struct HmuxVaultAgentPersistedSessionStoreTests {
    @Test("Parses every Hermes resume spelling", arguments: [
        ["--resume", "durable-session"],
        ["--resume=durable-session"],
        ["-r", "durable-session"],
        ["-r=durable-session"],
        ["-rdurable-session"],
    ])
    func parsesHermesResumeSpellings(arguments: [String]) {
        #expect(
            HmuxVaultAgentPersistedSessionStore.hermesStateDB
                .explicitSessionID(arguments: arguments) == "durable-session"
        )
    }
}
