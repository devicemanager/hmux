import HMUXAgentLaunch

extension HmuxVaultAgentRegistration {
    /// True only for hmux's exact built-in registration, not user registrations reusing its id.
    var isBuiltInKimi: Bool {
        self == Self.builtInKimi
    }

    static var builtInKimi: HmuxVaultAgentRegistration {
        HmuxVaultAgentRegistration(
            id: "kimi",
            name: RestorableAgentKind.kimi.displayName,
            detect: HmuxVaultAgentDetectRule(processNames: ["kimi", "kimi-cli", "kimi-code"]),
            sessionIdSource: .argvOption("--resume"),
            resumeCommand: RegisteredAgentResumeKind.kimi.commandTemplate,
            cwd: .preserve
        )
    }
}
