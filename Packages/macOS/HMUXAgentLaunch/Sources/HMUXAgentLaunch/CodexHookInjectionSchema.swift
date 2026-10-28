/// An ordered Codex hook block that hmux can generate or safely remove from
/// captured launch arguments.
public struct CodexHookInjectionSchema: Equatable, Sendable {
    /// The hook events in their required argument order.
    public let events: [CodexHookInjectionEvent]

    private init(events: [CodexHookInjectionEvent]) {
        self.events = events
    }

    /// The schema emitted by current hmux wrappers.
    ///
    /// Keep generation and replay
    /// sanitization on this shared value so a format change cannot update only
    /// one side of the boundary.
    public static let current = Self(events: [
        .init(agentEvent: "SessionStart", hmuxSubcommand: "session-start", timeoutMs: AgentHookDeliveryPolicy.declaredTimeoutMilliseconds),
        .init(
            agentEvent: "UserPromptSubmit",
            hmuxSubcommand: "prompt-submit",
            timeoutMs: AgentHookDeliveryPolicy.declaredTimeoutMilliseconds,
            companion: .init(hmuxSubcommand: "inbox-drain", timeoutMs: inboxHookTimeoutMilliseconds)
        ),
        .init(
            agentEvent: "Stop",
            hmuxSubcommand: "stop",
            timeoutMs: AgentHookDeliveryPolicy.declaredTimeoutMilliseconds,
            companion: .init(hmuxSubcommand: "inbox-stop", timeoutMs: inboxHookTimeoutMilliseconds)
        ),
        .init(agentEvent: "PreToolUse", hmuxSubcommand: "pre-tool-use", timeoutMs: AgentHookDeliveryPolicy.declaredTimeoutMilliseconds),
        .init(agentEvent: "PostToolUse", hmuxSubcommand: "post-tool-use", timeoutMs: AgentHookDeliveryPolicy.declaredTimeoutMilliseconds),
        .init(
            agentEvent: "PermissionRequest",
            hmuxSubcommand: "notification",
            timeoutMs: 120000,
            delivery: .direct
        ),
        .init(
            agentEvent: "SubagentStart",
            hmuxSubcommand: "subagent-start",
            timeoutMs: AgentHookDeliveryPolicy.declaredTimeoutMilliseconds,
            delivery: .direct
        ),
        .init(
            agentEvent: "SubagentStop",
            hmuxSubcommand: "subagent-stop",
            timeoutMs: AgentHookDeliveryPolicy.declaredTimeoutMilliseconds,
            delivery: .direct
        ),
    ])

    /// Timeout for the agent message handlers on UserPromptSubmit and Stop.
    /// They make one short socket call and fail open to `{}`.
    static let inboxHookTimeoutMilliseconds = 5_000

    /// Exact older shapes accepted by saved-layout and replay sanitization.
    /// These remain explicit because stored commands can outlive the hmux
    /// version that captured them. Never broaden this to unordered events or
    /// arbitrary prefixes: hook config is user-controlled argv.
    static let recognized = [
        current,
        // The generation before the agent message companions on
        // UserPromptSubmit and Stop.
        Self(events: [
            .init(agentEvent: "SessionStart", hmuxSubcommand: "session-start", timeoutMs: AgentHookDeliveryPolicy.declaredTimeoutMilliseconds),
            .init(agentEvent: "UserPromptSubmit", hmuxSubcommand: "prompt-submit", timeoutMs: AgentHookDeliveryPolicy.declaredTimeoutMilliseconds),
            .init(agentEvent: "Stop", hmuxSubcommand: "stop", timeoutMs: AgentHookDeliveryPolicy.declaredTimeoutMilliseconds),
            .init(agentEvent: "PreToolUse", hmuxSubcommand: "pre-tool-use", timeoutMs: AgentHookDeliveryPolicy.declaredTimeoutMilliseconds),
            .init(agentEvent: "PostToolUse", hmuxSubcommand: "post-tool-use", timeoutMs: AgentHookDeliveryPolicy.declaredTimeoutMilliseconds),
            .init(agentEvent: "PermissionRequest", hmuxSubcommand: "notification", timeoutMs: 120000, delivery: .direct),
            .init(agentEvent: "SubagentStart", hmuxSubcommand: "subagent-start", timeoutMs: AgentHookDeliveryPolicy.declaredTimeoutMilliseconds, delivery: .direct),
            .init(agentEvent: "SubagentStop", hmuxSubcommand: "subagent-stop", timeoutMs: AgentHookDeliveryPolicy.declaredTimeoutMilliseconds, delivery: .direct),
        ]),
        Self(events: [
            .init(agentEvent: "SessionStart", hmuxSubcommand: "session-start", timeoutMs: 10000),
            .init(agentEvent: "UserPromptSubmit", hmuxSubcommand: "prompt-submit", timeoutMs: 10000),
            .init(agentEvent: "Stop", hmuxSubcommand: "stop", timeoutMs: 10000),
            .init(agentEvent: "PreToolUse", hmuxSubcommand: "pre-tool-use", timeoutMs: 120000),
            .init(agentEvent: "PostToolUse", hmuxSubcommand: "post-tool-use", timeoutMs: 10000),
            .init(agentEvent: "PermissionRequest", hmuxSubcommand: "notification", timeoutMs: 120000, delivery: .direct),
            .init(agentEvent: "SubagentStart", hmuxSubcommand: "subagent-start", timeoutMs: 10000, delivery: .direct),
            .init(agentEvent: "SubagentStop", hmuxSubcommand: "subagent-stop", timeoutMs: 10000, delivery: .direct),
        ]),
        // The immediately previous wrapper generation had the same six
        // events but no native child callbacks. Keep it removable from saved
        // launch argv so an upgrade cannot leave two Stop producers active.
        Self(events: [
            .init(agentEvent: "SessionStart", hmuxSubcommand: "session-start", timeoutMs: 10000),
            .init(agentEvent: "UserPromptSubmit", hmuxSubcommand: "prompt-submit", timeoutMs: 10000),
            .init(agentEvent: "Stop", hmuxSubcommand: "stop", timeoutMs: 10000),
            .init(agentEvent: "PreToolUse", hmuxSubcommand: "pre-tool-use", timeoutMs: 120000),
            .init(agentEvent: "PostToolUse", hmuxSubcommand: "post-tool-use", timeoutMs: 10000),
            .init(agentEvent: "PermissionRequest", hmuxSubcommand: "notification", timeoutMs: 120000),
        ]),
        Self(events: [
            .init(agentEvent: "SessionStart", hmuxSubcommand: "session-start", timeoutMs: 10000),
            .init(agentEvent: "UserPromptSubmit", hmuxSubcommand: "prompt-submit", timeoutMs: 10000),
            .init(agentEvent: "Stop", hmuxSubcommand: "stop", timeoutMs: 10000),
            .init(agentEvent: "PreToolUse", hmuxSubcommand: "pre-tool-use", timeoutMs: 120000),
            .init(agentEvent: "PostToolUse", hmuxSubcommand: "post-tool-use", timeoutMs: 10000),
            .init(
                agentEvent: "PermissionRequest",
                hmuxSubcommand: "notification",
                timeoutMs: 120000,
                delivery: .direct
            ),
        ]),
        Self(events: [
            .init(agentEvent: "SessionStart", hmuxSubcommand: "session-start", timeoutMs: 10000),
            .init(agentEvent: "UserPromptSubmit", hmuxSubcommand: "prompt-submit", timeoutMs: 10000),
            .init(agentEvent: "PreToolUse", hmuxSubcommand: "pre-tool-use", timeoutMs: 10000),
            .init(agentEvent: "PostToolUse", hmuxSubcommand: "post-tool-use", timeoutMs: 10000),
            .init(agentEvent: "Notification", hmuxSubcommand: "notification", timeoutMs: 10000),
            .init(agentEvent: "Stop", hmuxSubcommand: "stop", timeoutMs: 10000),
        ]),
        Self(events: [
            .init(agentEvent: "SessionStart", hmuxSubcommand: "session-start", timeoutMs: 10000),
            .init(agentEvent: "SessionStop", hmuxSubcommand: "stop", timeoutMs: 10000),
            .init(agentEvent: "Notification", hmuxSubcommand: "notification", timeoutMs: 10000),
        ]),
    ]
}
