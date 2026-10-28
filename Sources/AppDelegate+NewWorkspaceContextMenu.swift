import HmuxCloud
import AppKit
import Foundation

// MARK: - New-workspace plus-button context menu

@MainActor
final class NewWorkspaceContextMenuActionBox: NSObject {
    let windowId: UUID
    let action: HmuxResolvedConfigAction

    init(windowId: UUID, action: HmuxResolvedConfigAction) {
        self.windowId = windowId
        self.action = action
    }
}

extension AppDelegate {

    @discardableResult
    func showNewWorkspaceContextMenu(
        anchorView: NSView,
        event: NSEvent,
        debugSource: String = "titlebar.newWorkspace.contextMenu"
    ) -> Bool {
        let context = contextForMainWindow(anchorView.window)
            ?? mainWindowContext(forShortcutEvent: event, debugSource: debugSource)
            ?? preferredMainWindowContextForWorkspaceCreation(event: event, debugSource: debugSource)
        guard let context,
              let hmuxConfigStore = context.hmuxConfigStore else {
            return false
        }

        guard let menu = makeNewWorkspaceContextMenu(
            context: context,
            hmuxConfigStore: hmuxConfigStore
        ) else {
            return false
        }

        NSMenu.popUpContextMenu(menu, with: event, for: anchorView)
        return true
    }

    /// Pops the menu below `anchorView`, or at `location` (in `anchorView`
    /// coordinates) when the caller only knows where the click landed.
    @discardableResult
    func showNewWorkspaceContextMenu(
        anchorView: NSView,
        at location: NSPoint? = nil,
        debugSource: String = "titlebar.newWorkspace.contextMenu"
    ) -> Bool {
        let context = contextForMainWindow(anchorView.window)
            ?? preferredMainWindowContextForWorkspaceCreation(event: nil, debugSource: debugSource)
        guard let context,
              let hmuxConfigStore = context.hmuxConfigStore else {
            return false
        }

        guard let menu = makeNewWorkspaceContextMenu(
            context: context,
            hmuxConfigStore: hmuxConfigStore
        ) else {
            return false
        }

        menu.popUp(
            positioning: nil,
            at: location ?? NSPoint(x: 0, y: anchorView.bounds.maxY + 2),
            in: anchorView
        )
        return true
    }

    func makeNewWorkspaceContextMenu(
        context: MainWindowContext,
        hmuxConfigStore: HmuxConfigStore,
        isAuthenticated: Bool? = nil
    ) -> NSMenu? {
        let isAuthenticated = isAuthenticated ?? (AppDelegate.shared?.auth?.accountFlow.isAuthenticated == true)
        let model = NewWorkspaceMenuModel.build(
            newWorkspaceContextMenuItems: hmuxConfigStore.newWorkspaceContextMenuItems.filter { item in
                guard case .action(let menuAction) = item,
                      case .builtIn(let builtIn) = menuAction.action.action else { return true }
                return Self.isBuiltInActionAvailableInNewWorkspaceMenu(builtIn, isAuthenticated: isAuthenticated)
            },
            agentChatAction: resolvedBuiltInNewAgentChatAction(hmuxConfigStore: hmuxConfigStore),
            templateNames: savedLayoutNames(),
            loadedActions: hmuxConfigStore.loadedActions,
            newWorkspaceActionID: hmuxConfigStore.newWorkspaceActionID,
            deletable: { [weak self, weak hmuxConfigStore] action in
                guard let self, let hmuxConfigStore else { return false }
                return isDeletableGlobalAction(action, hmuxConfigStore: hmuxConfigStore)
            }
        )
        return renderNewWorkspaceContextMenu(
            model: model,
            context: context,
            hmuxConfigStore: hmuxConfigStore
        )
    }

    /// Feature gates for built-in plus-menu rows, evaluated when the menu
    /// opens (not at config load) so flag and setting flips apply at once.
    /// Mirrors the command palette's gates for the same actions.
    static func isBuiltInActionAvailableInNewWorkspaceMenu(
        _ action: HmuxSurfaceTabBarBuiltInAction,
        isAuthenticated: Bool? = nil
    ) -> Bool {
        switch action {
        case .newCloudWorkspace, .newCloudMachine, .cloudVM:
            return CloudMachinesFeature.isEnabled
                && (isAuthenticated ?? (AppDelegate.shared?.auth?.accountFlow.isAuthenticated == true))
        case .newBrowser, .newAgentChat:
            return BrowserAvailabilitySettings.isEnabled()
        case .newSimulator:
            return HmuxFeatureFlags.shared.isSimulatorEnabled
        case .mobileConnect:
            return !MobileRemoteControlPolicy.isDisabled
        case .newWorkspace, .newTerminal, .splitRight, .splitDown,
             .copyWorkingDirectory, .copyProjectRoot, .copyScreen:
            return true
        }
    }

    private func savedLayoutNames() -> [String] {
        ((try? SavedLayoutStore().list()) ?? []).map(\.name)
    }

    private func resolvedBuiltInNewAgentChatAction(
        hmuxConfigStore: HmuxConfigStore
    ) -> HmuxResolvedConfigAction? {
        // Agent chat opens a browser surface; hide it when browser surfaces
        // are disabled, matching the command palette's browserDisabled gate.
        guard HmuxFeatureFlags.shared.isAgentChatUIEnabled else { return nil }
        guard BrowserAvailabilitySettings.isEnabled() else { return nil }
        let actionID = HmuxSurfaceTabBarBuiltInAction.newAgentChat.configID
        let action = hmuxConfigStore.resolvedAction(id: actionID)
            ?? .builtIn(.newAgentChat)
        guard shouldAppendBuiltInNewAgentChatMenuItem(
            action,
            actionID: actionID,
            hmuxConfigStore: hmuxConfigStore
        ) else {
            return nil
        }
        return action
    }

    private func shouldAppendBuiltInNewAgentChatMenuItem(
        _ action: HmuxResolvedConfigAction,
        actionID: String,
        hmuxConfigStore: HmuxConfigStore
    ) -> Bool {
        if action.newWorkspaceMenu == false { return false }
        let configuredActionIDs = Set(hmuxConfigStore.newWorkspaceContextMenuItems.compactMap { item -> String? in
            guard case .action(let menuAction) = item else { return nil }
            return menuAction.action.id
        })
        if configuredActionIDs.contains(actionID) { return false }
        return true
    }

    @objc func performNewWorkspaceContextMenuItem(_ sender: NSMenuItem) {
        guard let box = sender.representedObject as? NewWorkspaceContextMenuActionBox,
              let context = mainWindowContexts.values.first(where: { $0.windowId == box.windowId }),
              let window = resolvedWindow(for: context) else {
            NSSound.beep()
            return
        }
        let didExecute: Bool
        if case .builtIn(.newWorkspace) = box.action.action {
            didExecute = performNewWorkspaceAction(
                tabManager: context.tabManager,
                debugSource: "newWorkspace.contextMenu",
                skipConfiguredAction: true
            )
        } else {
            didExecute = executeConfiguredHmuxAction(box.action, context: context, preferredWindow: window)
        }
        guard didExecute else {
            NSSound.beep()
            return
        }
    }
}
