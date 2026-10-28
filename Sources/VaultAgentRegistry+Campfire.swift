import HMUXAgentLaunch

extension HmuxVaultAgentRegistration {
    static var builtInCampfire: HmuxVaultAgentRegistration {
        HmuxVaultAgentRegistration(
            id: "campfire",
            name: "Campfire",
            detect: HmuxVaultAgentDetectRule(
                processName: "campfire",
                alternateProcessNames: ["bun", "node", "deno", "tsx", "ts-node"],
                alternateArgvContainsAny: [
                    "packages/session/bin/campfire.ts",
                    "packages/session/dist/campfire",
                ]
            ),
            sessionIdSource: .argvOption("--session"),
            resumeCommand: RegisteredAgentResumeKind.campfire.commandTemplate,
            cwd: .preserve,
            sessionDirectory: "~/.campfire/agent/sessions"
        )
    }
}
