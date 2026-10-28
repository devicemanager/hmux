/// The settings-derived inputs ``TerminalSurface`` folds into a spawned
/// process's environment.
///
/// The surface model reads these through
/// ``TerminalSurfaceSpawnPolicyProviding`` at the exact point the legacy code
/// read the individual settings stores, so each spawn observes the same live
/// values in the same order.
public struct TerminalSurfaceSpawnPolicy: Sendable {
    /// Protected authentication values exported into the spawned terminal.
    public var socketAuthenticationEnvironment: [String: String]

    /// Whether Claude Code hooks are enabled (`HMUX_CLAUDE_HOOKS_DISABLED`).
    public var claudeHooksEnabled: Bool

    /// Whether Codex hooks (the `codex` wrapper) are enabled
    /// (`HMUX_CODEX_HOOKS_DISABLED`).
    public var codexHooksEnabled: Bool

    /// Whether Pi hooks (the `pi` wrapper and bundled extension) are enabled
    /// (`HMUX_PI_HOOKS_DISABLED`).
    public var piHooksEnabled: Bool

    /// The user's custom `claude` executable path
    /// (`HMUX_CUSTOM_CLAUDE_PATH`), if set.
    public var customClaudePath: String?

    /// Agent command shims enabled for this spawn.
    ///
    /// Claude's integration toggle controls command interception entirely;
    /// the other wrappers keep their existing launch behavior.
    public var enabledAgentCommandShims: Set<TerminalSurfaceAgentCommand> {
        var commands = Set(TerminalSurfaceAgentCommand.allCases)
        if !claudeHooksEnabled {
            commands.remove(.claude)
        }
        if !piHooksEnabled {
            commands.remove(.pi)
        }
        return commands
    }

    /// The environment key carrying the subagent-notification suppression
    /// flag.
    public var subagentNotificationEnvironmentKey: String

    /// Whether subagent notifications are suppressed (exported as `"1"`/`"0"`
    /// under ``subagentNotificationEnvironmentKey``).
    public var suppressSubagentNotifications: Bool

    /// Whether Cursor hooks are enabled (`HMUX_CURSOR_HOOKS_DISABLED`).
    public var cursorHooksEnabled: Bool

    /// Whether Gemini hooks are enabled (`HMUX_GEMINI_HOOKS_DISABLED`).
    public var geminiHooksEnabled: Bool

    /// Whether Kiro hooks are enabled (`HMUX_KIRO_HOOKS_DISABLED`).
    public var kiroHooksEnabled: Bool

    /// The Kiro notification level raw value
    /// (`HMUX_KIRO_NOTIFICATION_LEVEL`).
    public var kiroNotificationLevel: String

    /// Whether Amp hooks are enabled (`HMUX_AMP_HOOKS_DISABLED`).
    public var ampHooksEnabled: Bool

    /// Whether hmux shell integration is enabled (the
    /// `sidebarShellIntegration` setting).
    public var shellIntegrationEnabled: Bool

    /// Whether sidebar git-status watching is enabled (`HMUX_NO_GIT_WATCH`).
    public var watchGitStatusEnabled: Bool

    /// Whether sidebar pull-request watching is enabled (`HMUX_NO_PR_WATCH`).
    public var showPullRequestsEnabled: Bool

    /// Whether supported agent sessions may attach the local computer-use MCP server.
    public var computerUseEnabled: Bool

    /// Creates a spawn policy snapshot.
    public init(
        socketAuthenticationEnvironment: [String: String] = [:],
        claudeHooksEnabled: Bool,
        codexHooksEnabled: Bool = true,
        customClaudePath: String?,
        subagentNotificationEnvironmentKey: String,
        suppressSubagentNotifications: Bool,
        cursorHooksEnabled: Bool,
        geminiHooksEnabled: Bool,
        kiroHooksEnabled: Bool,
        kiroNotificationLevel: String,
        ampHooksEnabled: Bool,
        shellIntegrationEnabled: Bool,
        watchGitStatusEnabled: Bool,
        showPullRequestsEnabled: Bool,
        computerUseEnabled: Bool = true,
        piHooksEnabled: Bool = true
    ) {
        self.socketAuthenticationEnvironment = socketAuthenticationEnvironment
        self.claudeHooksEnabled = claudeHooksEnabled
        self.codexHooksEnabled = codexHooksEnabled
        self.piHooksEnabled = piHooksEnabled
        self.customClaudePath = customClaudePath
        self.subagentNotificationEnvironmentKey = subagentNotificationEnvironmentKey
        self.suppressSubagentNotifications = suppressSubagentNotifications
        self.cursorHooksEnabled = cursorHooksEnabled
        self.geminiHooksEnabled = geminiHooksEnabled
        self.kiroHooksEnabled = kiroHooksEnabled
        self.kiroNotificationLevel = kiroNotificationLevel
        self.ampHooksEnabled = ampHooksEnabled
        self.shellIntegrationEnabled = shellIntegrationEnabled
        self.watchGitStatusEnabled = watchGitStatusEnabled
        self.showPullRequestsEnabled = showPullRequestsEnabled
        self.computerUseEnabled = computerUseEnabled
    }
}
