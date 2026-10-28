/// Agent commands that hmux can intercept with a per-surface launch shim.
public enum TerminalSurfaceAgentCommand: String, CaseIterable, Hashable, Sendable {
    case claude
    case codex
    case pi
    case amp
    case hermes
    case agy
}

/// Describes one agent command intercepted by the shared per-surface shim path.
struct TerminalSurfaceAgentCommandShimDefinition: Sendable {
    let command: TerminalSurfaceAgentCommand
    let wrapperName: String
    let environmentVariablePrefix: String

    var commandName: String { command.rawValue }

    /// The single capability table for hmux-managed agent launch wrappers.
    static let bundled: [Self] = [
        Self(
            command: .claude,
            wrapperName: "hmux-claude-wrapper",
            environmentVariablePrefix: "HMUX_CLAUDE"
        ),
        Self(
            command: .codex,
            wrapperName: "hmux-codex-wrapper",
            environmentVariablePrefix: "HMUX_CODEX"
        ),
        Self(
            command: .pi,
            wrapperName: "hmux-pi-wrapper",
            environmentVariablePrefix: "HMUX_PI"
        ),
        Self(
            command: .amp,
            wrapperName: "hmux-amp-wrapper",
            environmentVariablePrefix: "HMUX_AMP"
        ),
        Self(
            command: .hermes,
            wrapperName: "hmux-hermes-agent-wrapper",
            environmentVariablePrefix: "HMUX_HERMES_AGENT"
        ),
        Self(
            command: .agy,
            wrapperName: "agy",
            environmentVariablePrefix: "HMUX_AGY"
        ),
    ]
}
