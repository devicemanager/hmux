import Testing

#if canImport(hmux_DEV)
@testable import hmux_DEV
#elseif canImport(hmux)
@testable import hmux
#endif

@Suite struct RemoteTmuxAgentStatusTests {
    @Test(arguments: [
        ("claude", "working"), ("claude", "blocked"), ("claude", "idle"),
        ("codex", "working"), ("codex", "blocked"), ("codex", "idle")
    ])
    func parsesHookContract(agent: String, state: String) {
        let status = RemoteTmuxAgentStatus.parse("{\"agent\":\"\(agent)\",\"state\":\"\(state)\"}")
        #expect(status?.agent.rawValue == agent)
        #expect(status?.state.rawValue == state)
    }

    @Test(arguments: ["", "{}", "not json", "{\"agent\":\"codex\",\"state\":\"bogus\"}",
                      "{\"agent\":\"bogus\",\"state\":\"working\"}", String(repeating: "x", count: 1025)])
    func clearsMalformedOrAbsentStatus(raw: String) {
        #expect(RemoteTmuxAgentStatus.parse(raw) == nil)
    }
}
