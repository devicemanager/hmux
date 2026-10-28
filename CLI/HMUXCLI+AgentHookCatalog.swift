import HMUXAgentLaunch
import Foundation

extension HMUXCLI {
    // MARK: Agent definitions

    static let agentDefs: [AgentHookDef] = [
        AgentHookDef(
            name: "codex", displayName: "Codex", statusKey: "codex",
            configDir: ".codex", configFile: "hooks.json", configDirEnvOverride: "CODEX_HOME",
            sessionStoreSuffix: "codex", disableEnvVar: "HMUX_CODEX_HOOKS_DISABLED",
            hookMarker: "hmux hooks codex", format: .nested(timeoutMs: agentHookDeclaredTimeoutMilliseconds),
            events: [
                .init(agentEvent: "SessionStart", hmuxSubcommand: "session-start"),
                .init(agentEvent: "UserPromptSubmit", hmuxSubcommand: "prompt-submit"),
                .init(agentEvent: "Stop", hmuxSubcommand: "stop"),
            ],
            feedHookEvents: [
                "PreToolUse",
                "PermissionRequest",
                "PostToolUse",
                "PreCompact",
                "PostCompact",
                "SubagentStart",
                "SubagentStop",
            ],
            postInstallAction: .codexConfigToml
        ),
        AgentHookDef(
            name: "grok", displayName: "Grok", statusKey: "grok",
            configDir: ".grok/hooks", configFile: "hmux-session.json",
            configDirEnvOverride: "GROK_HOME", configDirEnvOverrideSubpath: "hooks",
            createConfigDirIfMissing: true,
            sessionStoreSuffix: "grok", disableEnvVar: "HMUX_GROK_HOOKS_DISABLED",
            hookMarker: "hmux hooks grok", format: .nested(timeoutMs: 5000),
            events: [
                .init(agentEvent: "SessionStart", hmuxSubcommand: "session-start"),
                .init(agentEvent: "UserPromptSubmit", hmuxSubcommand: "prompt-submit"),
                .init(agentEvent: "Stop", hmuxSubcommand: "stop"),
                .init(agentEvent: "Notification", hmuxSubcommand: "notification"),
                .init(agentEvent: "SessionEnd", hmuxSubcommand: "session-end"),
            ],
            dispatch: .pinned(marker: "hmux-grok-hook-v2"),
            publishesStopNotification: false,
            sessionEndIsTurnBoundary: true,
            feedHookEvents: ["PreToolUse"]
        ),
        AgentHookDef(
            name: "opencode", displayName: "OpenCode", statusKey: "opencode",
            configDir: ".config/opencode", configFile: "plugins/hmux-session.js", configDirEnvOverride: "OPENCODE_CONFIG_DIR",
            configDirResolver: { OpenCodePaths(environment: ProcessInfo.processInfo.environment).configDirectory.path },
            sessionStoreSuffix: "opencode", disableEnvVar: "HMUX_OPENCODE_HOOKS_DISABLED",
            hookMarker: "hmux hooks opencode", format: .flat,
            events: []
        ),
        AgentHookDef(
            name: "pi", displayName: "Pi", statusKey: "pi",
            configDir: ".pi/agent", configFile: "extensions/hmux-session.ts", configDirEnvOverride: "PI_CODING_AGENT_DIR",
            sessionStoreSuffix: "pi", disableEnvVar: "HMUX_PI_HOOKS_DISABLED",
            hookMarker: "hmux hooks pi", format: .flat,
            events: []
        ),
        AgentHookDef(
            name: "omp", displayName: "OMP", statusKey: "omp",
            configDir: ".omp/agent", configFile: "extensions/hmux-omp-session.ts",
            createConfigDirIfMissing: true,
            configDirResolver: { HMUXCLI.resolvedOmpAgentDirectory().path },
            sessionStoreSuffix: "omp", disableEnvVar: "HMUX_OMP_HOOKS_DISABLED",
            hookMarker: "hmux hooks omp", format: .flat,
            events: []
        ),
        AgentHookDef(
            name: "campfire", displayName: "Campfire", statusKey: "campfire",
            configDir: ".campfire/agent", configFile: "extensions/hmux-campfire-session.ts",
            createConfigDirIfMissing: true,
            configDirResolver: { HMUXCLI.resolvedCampfireAgentDirectory().path },
            sessionStoreSuffix: "campfire", disableEnvVar: "HMUX_CAMPFIRE_HOOKS_DISABLED",
            hookMarker: "hmux hooks campfire", format: .flat,
            events: []
        ),
        AgentHookDef(
            name: "amp", displayName: "Amp", statusKey: "amp",
            configDir: ".config/amp", configFile: "plugins/hmux-session.ts",
            sessionStoreSuffix: "amp", disableEnvVar: "HMUX_AMP_HOOKS_DISABLED",
            hookMarker: "hmux hooks amp", format: .flat,
            events: []
        ),
        AgentHookDef(
            name: "cursor", displayName: "Cursor", statusKey: "cursor",
            configDir: ".cursor", configFile: "hooks.json", binaryName: "cursor-agent",
            sessionStoreSuffix: "cursor", disableEnvVar: "HMUX_CURSOR_HOOKS_DISABLED",
            hookMarker: "hmux hooks cursor", format: .flat,
            events: [
                .init(agentEvent: "beforeSubmitPrompt", hmuxSubcommand: "prompt-submit"),
                .init(agentEvent: "stop", hmuxSubcommand: "stop"),
                .init(agentEvent: "afterAgentResponse", hmuxSubcommand: "agent-response"),
                .init(
                    agentEvent: "beforeShellExecution",
                    hmuxSubcommand: "shell-exec",
                    delivery: .direct
                ),
                .init(agentEvent: "afterShellExecution", hmuxSubcommand: "shell-done"),
                .init(
                    agentEvent: "postToolUseFailure",
                    hmuxSubcommand: "shell-failed",
                    matcher: "Shell"
                ),
            ]
        ),
        AgentHookDef(
            name: "gemini", displayName: "Gemini", statusKey: "gemini",
            configDir: ".gemini", configFile: "settings.json",
            sessionStoreSuffix: "gemini", disableEnvVar: "HMUX_GEMINI_HOOKS_DISABLED",
            hookMarker: "hmux hooks gemini", format: .nested(timeoutMs: 10000),
            events: [
                .init(agentEvent: "SessionStart", hmuxSubcommand: "session-start"),
                .init(agentEvent: "BeforeAgent", hmuxSubcommand: "prompt-submit"),
                .init(agentEvent: "AfterAgent", hmuxSubcommand: "stop"),
                .init(agentEvent: "SessionEnd", hmuxSubcommand: "session-end"),
            ],
            feedHookEvents: ["PreToolUse"]
        ),
        AgentHookDef(
            name: "kiro", displayName: "Kiro", statusKey: "kiro",
            configDir: ".kiro/agents", configFile: "hmux.json",
            configDirEnvOverride: "KIRO_HOME", configDirEnvOverrideSubpath: "agents",
            createConfigDirIfMissing: true, binaryName: "kiro-cli",
            sessionStoreSuffix: "kiro", disableEnvVar: "HMUX_KIRO_HOOKS_DISABLED",
            hookMarker: "hmux hooks kiro", format: .kiroAgentJSON(timeoutMs: 5000),
            events: [
                .init(agentEvent: "agentSpawn", hmuxSubcommand: "session-start"),
                .init(agentEvent: "userPromptSubmit", hmuxSubcommand: "prompt-submit"),
                .init(agentEvent: "stop", hmuxSubcommand: "stop"),
            ],
            feedHookEvents: ["preToolUse", "postToolUse"],
            postInstallNote: String(
                localized: "cli.hooks.kiro.postInstallNote",
                defaultValue: "Kiro applies these hooks only when run as the hmux agent. Start Kiro with `kiro-cli chat --agent hmux`, or make it the default with `kiro-cli settings chat.defaultAgent hmux`."
            )
        ),
        AgentHookDef(
            name: "antigravity", displayName: "Antigravity", statusKey: "antigravity",
            configDir: ".gemini/config", configFile: "hooks.json",
            createConfigDirIfMissing: true, binaryName: "agy",
            sessionStoreSuffix: "antigravity", disableEnvVar: "HMUX_ANTIGRAVITY_HOOKS_DISABLED",
            hookMarker: "hmux hooks antigravity", format: .antigravityJSON(timeoutSeconds: 10),
            events: [
                .init(agentEvent: "SessionStart", hmuxSubcommand: "session-start"),
                .init(agentEvent: "PreInvocation", hmuxSubcommand: "prompt-submit"),
                .init(agentEvent: "Stop", hmuxSubcommand: "stop"),
                .init(agentEvent: "turn-completion", hmuxSubcommand: "stop"),
                .init(agentEvent: "Notification", hmuxSubcommand: "notification"),
                .init(agentEvent: "SessionEnd", hmuxSubcommand: "session-end"),
            ],
            aliases: ["agy"],
            dispatch: .pinned(marker: "hmux-antigravity-hook-v2"),
            sessionEndIsTurnBoundary: true
        ),
        AgentHookDef(
            name: "rovodev", displayName: "Rovo Dev", statusKey: "rovodev",
            configDir: ".rovodev", configFile: "config.yml", binaryName: "acli",
            sessionStoreSuffix: "rovodev", disableEnvVar: "HMUX_ROVODEV_HOOKS_DISABLED",
            hookMarker: "hmux hooks rovodev", format: .rovoDevYAML,
            events: [
                .init(agentEvent: "on_complete", hmuxSubcommand: "stop"),
                .init(agentEvent: "on_error", hmuxSubcommand: "stop"),
                .init(agentEvent: "on_tool_permission", hmuxSubcommand: "prompt-submit"),
            ],
            aliases: ["rovo"]
        ),
        AgentHookDef(
            name: "hermes-agent", displayName: "Hermes Agent", statusKey: "hermes-agent",
            configDir: ".hermes", configFile: "config.yaml", configDirEnvOverride: "HERMES_HOME",
            createConfigDirIfMissing: true,
            binaryName: "hermes",
            sessionStoreSuffix: "hermes-agent", disableEnvVar: "HMUX_HERMES_AGENT_HOOKS_DISABLED",
            hookMarker: "hmux hooks hermes-agent", format: .hermesAgentYAML,
            events: [
                .init(agentEvent: "on_session_start", hmuxSubcommand: "session-start"),
                .init(agentEvent: "pre_llm_call", hmuxSubcommand: "prompt-submit"),
                .init(agentEvent: "post_llm_call", hmuxSubcommand: "agent-response"),
                .init(agentEvent: "pre_approval_request", hmuxSubcommand: "notification"),
                .init(agentEvent: "post_approval_response", hmuxSubcommand: "approval-response"),
                .init(agentEvent: "on_session_end", hmuxSubcommand: "session-end"),
                .init(agentEvent: "on_session_finalize", hmuxSubcommand: "session-finalize"),
                .init(agentEvent: "on_session_reset", hmuxSubcommand: "session-start"),
            ],
            sessionEndIsTurnBoundary: true,
            feedHookEvents: ["pre_tool_call", "post_tool_call", "pre_approval_request", "post_approval_response"]
        ),
        // Copilot CLI loads every `*.json` under `~/.copilot/hooks/` (or
        // `$COPILOT_HOME/hooks/`) and no longer reads hooks from `config.json`,
        // so hmux owns one whole file there. Events use Copilot's camelCase
        // names; see docs.github.com's Copilot CLI hooks reference.
        AgentHookDef(
            name: "copilot", displayName: "Copilot", statusKey: "copilot",
            configDir: ".copilot", configFile: "hooks/hmux.json", configDirEnvOverride: "COPILOT_HOME",
            sessionStoreSuffix: "copilot", disableEnvVar: "HMUX_COPILOT_HOOKS_DISABLED",
            hookMarker: "hmux hooks copilot", format: .copilotHooksJSON(timeoutSeconds: 5),
            events: [
                .init(agentEvent: "sessionStart", hmuxSubcommand: "session-start"),
                .init(agentEvent: "agentStop", hmuxSubcommand: "stop"),
                .init(agentEvent: "notification", hmuxSubcommand: "stop"),
                .init(agentEvent: "sessionEnd", hmuxSubcommand: "session-end"),
            ],
            feedHookEvents: ["preToolUse"]
        ),
        AgentHookDef(
            name: "codebuddy", displayName: "CodeBuddy", statusKey: "codebuddy",
            configDir: ".codebuddy", configFile: "settings.json", configDirEnvOverride: "CODEBUDDY_CONFIG_DIR",
            sessionStoreSuffix: "codebuddy", disableEnvVar: "HMUX_CODEBUDDY_HOOKS_DISABLED",
            hookMarker: "hmux hooks codebuddy", format: .nested(timeoutMs: 5000),
            events: [
                .init(agentEvent: "SessionStart", hmuxSubcommand: "session-start"),
                .init(agentEvent: "Stop", hmuxSubcommand: "stop"),
                .init(agentEvent: "Notification", hmuxSubcommand: "stop"),
                .init(agentEvent: "SessionEnd", hmuxSubcommand: "session-end"),
            ],
            feedHookEvents: ["PreToolUse"]
        ),
        AgentHookDef(
            name: "factory", displayName: "Factory", statusKey: "factory",
            configDir: ".factory", configFile: "settings.json", binaryName: "droid",
            sessionStoreSuffix: "factory", disableEnvVar: "HMUX_FACTORY_HOOKS_DISABLED",
            hookMarker: "hmux hooks factory", format: .nested(timeoutMs: 5000),
            events: [
                .init(agentEvent: "SessionStart", hmuxSubcommand: "session-start"),
                .init(agentEvent: "Stop", hmuxSubcommand: "stop"),
                .init(agentEvent: "Notification", hmuxSubcommand: "stop"),
                .init(agentEvent: "SessionEnd", hmuxSubcommand: "session-end"),
            ],
            feedHookEvents: ["PreToolUse"]
        ),
        AgentHookDef(
            name: "qoder", displayName: "Qoder", statusKey: "qoder",
            configDir: ".qoder", configFile: "settings.json", configDirEnvOverride: "QODER_CONFIG_DIR", binaryName: "qodercli",
            sessionStoreSuffix: "qoder", disableEnvVar: "HMUX_QODER_HOOKS_DISABLED",
            hookMarker: "hmux hooks qoder", format: .nested(timeoutMs: 5000),
            events: [
                .init(agentEvent: "SessionStart", hmuxSubcommand: "session-start"),
                .init(agentEvent: "Stop", hmuxSubcommand: "stop"),
                .init(agentEvent: "SessionEnd", hmuxSubcommand: "session-end"),
            ],
            feedHookEvents: ["PreToolUse"]
        ),
        AgentHookDef(
            name: "kimi", displayName: "Kimi Code", statusKey: "kimi",
            configDir: KimiConfigLocationResolver.kimiCodeConfigDirectory,
            configFile: KimiConfigLocationResolver.configFileName,
            createConfigDirIfMissing: true,
            configDirResolver: { HMUXCLI.resolvedKimiConfigDirectory().path },
            binaryName: "kimi",
            sessionStoreSuffix: "kimi", disableEnvVar: "HMUX_KIMI_HOOKS_DISABLED",
            hookMarker: "hmux hooks kimi", format: .tomlArrayTable,
            events: [
                .init(agentEvent: "SessionStart", hmuxSubcommand: "session-start"),
                .init(agentEvent: "UserPromptSubmit", hmuxSubcommand: "prompt-submit"),
                .init(agentEvent: "Notification", hmuxSubcommand: "notification"),
                .init(agentEvent: "Stop", hmuxSubcommand: "stop"),
                .init(agentEvent: "StopFailure", hmuxSubcommand: "notification"),
                .init(agentEvent: "SessionEnd", hmuxSubcommand: "session-end"),
            ],
            feedHookEvents: ["PreToolUse", "PostToolUse"]
        ),
        AgentHookDef(
            name: "muse", displayName: "Muse Code", statusKey: "muse",
            configDir: ".config/muse", configFile: "settings.json",
            configDirEnvOverride: "XDG_CONFIG_HOME", configDirEnvOverrideSubpath: "muse",
            createConfigDirIfMissing: true,
            sessionStoreSuffix: "muse", disableEnvVar: "HMUX_MUSE_HOOKS_DISABLED",
            hookMarker: "hmux hooks muse", format: .nested(timeoutMs: 10_000),
            events: [
                .init(agentEvent: "SessionStart", hmuxSubcommand: "session-start"),
                .init(agentEvent: "UserPromptSubmit", hmuxSubcommand: "prompt-submit"),
                .init(agentEvent: "Stop", hmuxSubcommand: "stop"),
                .init(agentEvent: "StopFailure", hmuxSubcommand: "notification"),
                .init(agentEvent: "Notification", hmuxSubcommand: "notification"),
                .init(agentEvent: "SessionEnd", hmuxSubcommand: "session-end"),
            ],
            // Muse runs hooks with a cleared environment, so hooks reach hmux
            // through the installing CLI and socket.
            dispatch: .pinned(marker: "hmux-muse-hook-v1")
        ),
    ]

    /// The agents `hmux hooks <agent> ...` and `hmux hooks setup --agent <name>`
    /// accept, derived from the same catalog `agentDef(named:)` resolves against,
    /// so catalog aliases are offered alongside primary names.
    static let hookAgentNames: [String] = Set(agentDefs.flatMap { [$0.name] + $0.aliases }).sorted()

    /// Completion candidates for the first token of `hmux hooks`: the
    /// catalog-wide verbs `hmux hooks --help` documents plus every agent. `hooks`
    /// stays an unrecognized-argument sink rather than a subcommand tree because
    /// past the first token it dispatches into the per-agent event entrypoints
    /// that generated configs own, and declaring those would put internal hook
    /// events in the user-facing tree.
    static let hooksTargetNames: [String] = ["setup", "uninstall", "feed"] + hookAgentNames

    static func agentDef(named name: String) -> AgentHookDef? {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return agentDefs.first { $0.name == normalized || $0.aliases.contains(normalized) }
    }
}
