import Foundation
import Testing
@testable import HmuxMobileShellModel

@Suite struct MobileTaskCommandComposerTests {
    private let composer = MobileTaskCommandComposer()

    @Test func whitespaceOnlyCommandsCreatePlainShells() {
        for command in ["", " ", " \n\t "] {
            let template = MobileTaskTemplate(name: "Shell", icon: "terminal", command: command)
            let result = composer.compose(template: template, prompt: "Investigate logs")

            #expect(template.isPlainShell)
            #expect(result.initialCommand == nil)
            #expect(result.initialEnv.isEmpty)
            #expect(result.title == "Investigate logs")
        }
    }

    @Test func nonblankCommandAndBlankPromptRemainExplicit() {
        let command = "codex -- \"$HMUX_TASK_PROMPT\""
        let template = MobileTaskTemplate(name: "Codex", icon: "agent:codex", command: command)

        let result = composer.compose(template: template, prompt: " \n ")

        #expect(!template.isPlainShell)
        #expect(result.initialCommand == command)
        #expect(result.initialEnv == ["HMUX_TASK_PROMPT": ""])
        #expect(result.title == nil)
    }

    @Test func promptIsTrimmedOnlyInEnvironmentAndTitle() {
        let command = "agent --flag"
        let template = MobileTaskTemplate(name: "Agent", icon: "terminal", command: command)

        let result = composer.compose(template: template, prompt: "  Fix the race  \n ")

        #expect(result.initialCommand == command)
        #expect(result.initialEnv == ["HMUX_TASK_PROMPT": "Fix the race"])
        #expect(result.title == "Fix the race")
    }

    @Test func seededCommandsConsumeThePromptEnvironmentExplicitly() {
        let seeds = MobileTaskTemplate.seedDefaults(
            claudeName: "Claude",
            codexName: "Codex",
            openCodeName: "OpenCode",
            shellName: "Shell"
        )

        #expect(seeds.map(\.command) == [
            "claude -- \"$HMUX_TASK_PROMPT\"",
            "codex -- \"$HMUX_TASK_PROMPT\"",
            "opencode --prompt \"$HMUX_TASK_PROMPT\"",
            "",
        ])
        for template in seeds.dropLast() {
            let result = composer.compose(template: template, prompt: "--resume")
            #expect(result.initialCommand == template.command)
            #expect(result.initialEnv == ["HMUX_TASK_PROMPT": "--resume"])
        }
    }

    @Test func seededAgentCommandsApplySelectedModels() {
        let seeds = MobileTaskTemplate.seedDefaults(
            claudeName: "Claude",
            codexName: "Codex",
            openCodeName: "OpenCode",
            shellName: "Shell"
        )
        let cases = [
            (
                seeds[0],
                "claude-opus-4-8",
                "claude --model 'claude-opus-4-8' -- \"$HMUX_TASK_PROMPT\""
            ),
            (
                seeds[1],
                "gpt-5.5",
                "codex -m 'gpt-5.5' -- \"$HMUX_TASK_PROMPT\""
            ),
            (
                seeds[2],
                "openai/gpt-5.5",
                "opencode --model 'openai/gpt-5.5' --prompt \"$HMUX_TASK_PROMPT\""
            ),
        ]

        for (template, modelID, expectedCommand) in cases {
            let result = composer.compose(
                template: template,
                prompt: "  Fix the race  ",
                modelID: modelID
            )
            #expect(result.initialCommand == expectedCommand)
            #expect(result.initialEnv == ["HMUX_TASK_PROMPT": "Fix the race"])
            #expect(result.title == "Fix the race")
        }
    }

    @Test func modelSpecificEffortUsesEachProvidersNativeFlag() {
        let seeds = MobileTaskTemplate.seedDefaults(
            claudeName: "Claude",
            codexName: "Codex",
            openCodeName: "OpenCode",
            shellName: "Shell"
        )
        let cases = [
            (seeds[0], "claude-opus", "high", "claude --effort 'high' --model 'claude-opus' -- \"$HMUX_TASK_PROMPT\""),
            (seeds[1], "gpt-5.6", "medium", "codex -c model_reasoning_effort='medium' -m 'gpt-5.6' -- \"$HMUX_TASK_PROMPT\""),
            (seeds[2], "openai/gpt-5.6", "low", "opencode --variant 'low' --model 'openai/gpt-5.6' --prompt \"$HMUX_TASK_PROMPT\""),
        ]

        for (template, modelID, effortID, expectedCommand) in cases {
            let result = composer.compose(
                template: template,
                prompt: "Fix the race",
                modelID: modelID,
                effortID: effortID
            )
            #expect(result.initialCommand == expectedCommand)
        }
    }

    @Test func defaultModelEffortLeavesModelUnpinned() {
        let seeds = MobileTaskTemplate.seedDefaults(
            claudeName: "Claude",
            codexName: "Codex",
            openCodeName: "OpenCode",
            shellName: "Shell"
        )
        let cases = [
            (seeds[0], "claude --effort 'high' -- \"$HMUX_TASK_PROMPT\""),
            (seeds[1], "codex -c model_reasoning_effort='high' -- \"$HMUX_TASK_PROMPT\""),
            (seeds[2], "opencode --variant 'high' --prompt \"$HMUX_TASK_PROMPT\""),
        ]

        for (template, expectedCommand) in cases {
            let result = composer.compose(
                template: template,
                prompt: "Fix the race",
                modelID: nil,
                effortID: "high"
            )
            #expect(result.initialCommand == expectedCommand)
        }
    }

    @Test func selectedEffortReplacesEveryStaleProviderValue() {
        let cases = [
            (
                MobileTaskTemplate(name: "Claude", icon: "agent:claude", command: "claude --effort low --effort=medium"),
                "claude --effort 'high' --effort='high'"
            ),
            (
                MobileTaskTemplate(name: "Codex", icon: "agent:codex", command: "codex -c model_reasoning_effort='low' --config=model_reasoning_effort=medium"),
                "codex -c model_reasoning_effort='high' --config=model_reasoning_effort='high'"
            ),
            (
                MobileTaskTemplate(name: "OpenCode", icon: "agent:opencode", command: "opencode --variant low --variant=medium"),
                "opencode --variant 'high' --variant='high'"
            ),
        ]

        for (template, expectedCommand) in cases {
            #expect(composer.compose(
                template: template,
                prompt: "Fix",
                effortID: "high"
            ).initialCommand == expectedCommand)
        }
    }

    @Test func agentDiscoveredIdentifierFlowsToCommandWithoutDeviceCatalogKnowledge() {
        let template = MobileTaskTemplate(
            name: "Claude",
            icon: "agent:claude",
            command: "claude -- \"$HMUX_TASK_PROMPT\""
        )

        let result = composer.compose(
            template: template,
            prompt: "Use the host model",
            modelID: "host-next-999"
        )

        #expect(
            result.initialCommand
                == "claude --model 'host-next-999' -- \"$HMUX_TASK_PROMPT\""
        )
    }

    @Test func selectedModelKeepsPlainShellPlain() {
        let template = MobileTaskTemplate(name: "Shell", icon: "terminal", command: "")
        let result = composer.compose(
            template: template,
            prompt: "Run diagnostics",
            modelID: "gpt-5.5"
        )

        #expect(result.initialCommand == nil)
        #expect(result.initialEnv.isEmpty)
        #expect(result.title == "Run diagnostics")
    }

    @Test func attachmentPathsPopulateEnvironmentAndPromptSuffix() {
        let template = MobileTaskTemplate(
            name: "Codex",
            icon: "agent:codex",
            command: "codex -- \"$HMUX_TASK_PROMPT\""
        )
        let result = composer.compose(
            template: template,
            prompt: "  Investigate the failure  ",
            attachmentPaths: ["/tmp/one.png", "/tmp/two notes.txt"]
        )

        #expect(result.initialCommand == template.command)
        #expect(result.initialEnv == [
            "HMUX_TASK_ATTACHMENTS": "/tmp/one.png\n/tmp/two notes.txt",
            "HMUX_TASK_PROMPT": """
            Investigate the failure

            Attached files (absolute paths on this machine):
            - /tmp/one.png
            - /tmp/two notes.txt
            """,
        ])
    }

    @Test func emptyAttachmentPathsPreservePreviousCompositionExactly() {
        let template = MobileTaskTemplate(
            name: "Codex",
            icon: "agent:codex",
            command: "codex -- \"$HMUX_TASK_PROMPT\""
        )
        let baseline = composer.compose(template: template, prompt: "Ship it")
        let explicitEmpty = composer.compose(
            template: template,
            prompt: "Ship it",
            attachmentPaths: []
        )

        #expect(explicitEmpty == baseline)
    }

    @Test func plainShellIgnoresAttachmentPaths() {
        let template = MobileTaskTemplate(name: "Shell", icon: "terminal", command: "")
        let result = composer.compose(
            template: template,
            prompt: "Inspect this",
            attachmentPaths: ["/tmp/evidence.txt"]
        )

        #expect(result.initialCommand == nil)
        #expect(result.initialEnv.isEmpty)
    }

    @Test func selectedModelKeepsUnknownCommandVerbatim() {
        let command = "custom-agent -- \"$HMUX_TASK_PROMPT\""
        let template = MobileTaskTemplate(name: "Custom", icon: "terminal", command: command)
        let result = composer.compose(
            template: template,
            prompt: "Investigate",
            modelID: "gpt-5.5"
        )

        #expect(result.initialCommand == command)
        #expect(result.initialEnv == ["HMUX_TASK_PROMPT": "Investigate"])
        #expect(result.title == "Investigate")
    }

    @Test func submissionIdentityStaysStableUntilRotated() {
        let restoredID = UUID()
        var identity = MobileTaskSubmissionIdentity(id: restoredID)

        #expect(identity.id == restoredID)
        #expect(identity.id == restoredID)

        identity.rotate()

        #expect(identity.id != restoredID)
    }

    @Test func submissionSnapshotKeepsTheVerbatimCommand() {
        let operationID = UUID()
        let templateID = UUID()
        let template = MobileTaskTemplate(
            id: templateID,
            name: "Codex",
            icon: "sparkles",
            command: "codex {prompt}"
        )
        let snapshot = MobileTaskSubmissionSnapshot(
            template: template,
            prompt: "Fix the race",
            macDeviceID: "mac-a",
            directory: "  ~/hmux  ",
            didEditDirectory: true,
            operationID: operationID
        )

        #expect(snapshot.templateID == template.id)
        #expect(snapshot.macDeviceID == "mac-a")
        #expect(snapshot.trimmedDirectory == "~/hmux")
        #expect(snapshot.operationID == operationID)
        #expect(snapshot.composition.initialCommand == "codex {prompt}")
        #expect(snapshot.composition.initialEnv == ["HMUX_TASK_PROMPT": "Fix the race"])
        #expect(snapshot.draft == MobileTaskComposerDraft(
            prompt: "Fix the race",
            modelID: nil,
            templateID: template.id,
            macDeviceID: "mac-a",
            directory: "  ~/hmux  ",
            didEditDirectory: true,
            operationID: operationID
        ))
    }

    @Test func titleUsesFirstTrimmedLineAndTruncatesToSixtyCharacters() {
        let template = MobileTaskTemplate(name: "Codex", icon: "sparkles", command: "codex")
        let prompt = "  123456789012345678901234567890123456789012345678901234567890abcdef\nsecond line  "

        let result = composer.compose(template: template, prompt: prompt)

        #expect(result.title == "123456789012345678901234567890123456789012345678901234567890")
    }
}
