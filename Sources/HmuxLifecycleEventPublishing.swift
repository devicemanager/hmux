import Foundation
import AppKit
import Bonsplit

@MainActor
private enum HmuxSelectionEventState {
    static var selectedSurfaceByWorkspacePane: [String: UUID] = [:]
    static var focusedPaneByWorkspace: [UUID: UUID] = [:]
    static var focusedSurfaceByWorkspace: [UUID: UUID] = [:]

    static func paneKey(workspaceId: UUID, paneId: UUID) -> String {
        "\(workspaceId.uuidString):\(paneId.uuidString)"
    }

    static func clearWorkspace(_ workspaceId: UUID) {
        selectedSurfaceByWorkspacePane = selectedSurfaceByWorkspacePane.filter {
            !$0.key.hasPrefix("\(workspaceId.uuidString):")
        }
        focusedPaneByWorkspace.removeValue(forKey: workspaceId)
        focusedSurfaceByWorkspace.removeValue(forKey: workspaceId)
    }

    static func clearPane(workspaceId: UUID, paneId: UUID) {
        selectedSurfaceByWorkspacePane.removeValue(forKey: paneKey(workspaceId: workspaceId, paneId: paneId))
        if focusedPaneByWorkspace[workspaceId] == paneId {
            focusedPaneByWorkspace.removeValue(forKey: workspaceId)
        }
    }

    static func clearSurface(workspaceId: UUID, surfaceId: UUID) {
        selectedSurfaceByWorkspacePane = selectedSurfaceByWorkspacePane.filter { $0.value != surfaceId }
        if focusedSurfaceByWorkspace[workspaceId] == surfaceId {
            focusedSurfaceByWorkspace.removeValue(forKey: workspaceId)
        }
    }
}

extension TabManager {
    func publishHmuxWorkspaceCreated(_ workspace: Workspace, selected: Bool) {
        HmuxEventBus.shared.publishWorkspaceCreated(
            workspaceId: workspace.id,
            title: workspace.hmuxEventWorkspaceTitle,
            customTitle: workspace.customTitle,
            currentDirectory: workspace.currentDirectory,
            selected: selected,
            index: tabs.firstIndex(where: { $0.id == workspace.id }),
            tabCount: tabs.count
        )
    }

    func publishHmuxInitialSurfaceCreated(_ workspace: Workspace, selected: Bool) {
        guard let panelId = workspace.focusedSurfaceId,
              let panel = workspace.panels[panelId] else { return }
        workspace.publishHmuxSurfaceCreated(
            panelId,
            paneId: workspace.paneId(forPanelId: panelId),
            kind: Workspace.hmuxEventSurfaceKind(panel),
            origin: "workspace_initial",
            focused: selected
        )
    }

    func publishHmuxWorkspaceClosed(_ workspace: Workspace) {
        HmuxEventBus.shared.publishWorkspaceClosed(
            workspaceId: workspace.id,
            title: workspace.hmuxEventWorkspaceTitle,
            customTitle: workspace.customTitle,
            currentDirectory: workspace.currentDirectory,
            remainingTabCount: tabs.count
        )
        HmuxSelectionEventState.clearWorkspace(workspace.id)
    }

    func publishHmuxWorkspaceSelected(_ workspace: Workspace) {
        HmuxEventBus.shared.publishWorkspaceSelected(
            workspaceId: workspace.id,
            title: workspace.hmuxEventWorkspaceTitle,
            customTitle: workspace.customTitle,
            currentDirectory: workspace.currentDirectory,
            previousWorkspaceId: nil,
            index: tabs.firstIndex(where: { $0.id == workspace.id }),
            tabCount: tabs.count
        )
    }

    func publishHmuxWorkspaceSelectedChange(from previousWorkspaceId: UUID?) {
        AppDelegate.shared?.workspacePresenceController.refreshSelection()
        guard let selectedTabId,
              let workspace = tabs.first(where: { $0.id == selectedTabId }) else { return }
        HmuxEventBus.shared.publishWorkspaceSelected(
            workspaceId: workspace.id,
            title: workspace.hmuxEventWorkspaceTitle,
            customTitle: workspace.customTitle,
            currentDirectory: workspace.currentDirectory,
            previousWorkspaceId: previousWorkspaceId,
            index: tabs.firstIndex(where: { $0.id == workspace.id }),
            tabCount: tabs.count
        )
    }
}

extension Workspace {
    var hmuxEventWorkspaceTitle: String {
        customTitle ?? title
    }

    func publishHmuxSplitCreated(
        _ paneId: PaneID,
        sourcePaneId: PaneID?,
        orientation: SplitOrientation,
        surfaceId: UUID?,
        kind: String,
        origin: String,
        focused: Bool
    ) {
        HmuxEventBus.shared.publishPaneCreated(
            workspaceId: id,
            paneId: paneId.id,
            sourcePaneId: sourcePaneId?.id,
            orientation: orientation.rawValue,
            surfaceId: surfaceId,
            origin: origin
        )
        if let surfaceId {
            publishHmuxSurfaceCreated(surfaceId, paneId: paneId, kind: kind, origin: origin, focused: focused)
        }
    }

    func publishHmuxSurfaceCreated(
        _ surfaceId: UUID,
        paneId: PaneID?,
        kind: String,
        origin: String,
        focused: Bool
    ) {
        HmuxEventBus.shared.publishSurfaceCreated(
            workspaceId: id,
            surfaceId: surfaceId,
            paneId: paneId?.id,
            kind: kind,
            origin: origin,
            focused: focused
        )
    }

    func publishHmuxSurfaceClosed(_ surfaceId: UUID, paneId: PaneID?, panel: (any Panel)?, origin: String) {
        HmuxEventBus.shared.publishSurfaceClosed(
            workspaceId: id,
            surfaceId: surfaceId,
            paneId: paneId?.id,
            kind: panel.map(Self.hmuxEventSurfaceKind),
            origin: origin
        )
        HmuxSelectionEventState.clearSurface(workspaceId: id, surfaceId: surfaceId)
    }

    func publishHmuxPaneClosed(_ paneId: PaneID, closedPanelIds: [UUID], origin: String) {
        HmuxEventBus.shared.publishPaneClosed(
            workspaceId: id,
            paneId: paneId.id,
            closedSurfaceIds: closedPanelIds,
            origin: origin
        )
        HmuxSelectionEventState.clearPane(workspaceId: id, paneId: paneId.id)
    }

    func publishHmuxFocusedSelection(paneId: PaneID, surfaceId: UUID, origin: String) {
        let paneKey = HmuxSelectionEventState.paneKey(workspaceId: id, paneId: paneId.id)
        let previousSelectedSurfaceId = HmuxSelectionEventState.selectedSurfaceByWorkspacePane[paneKey]
        let kind = panels[surfaceId].map(Self.hmuxEventSurfaceKind)

        if previousSelectedSurfaceId != surfaceId {
            HmuxSelectionEventState.selectedSurfaceByWorkspacePane[paneKey] = surfaceId
            HmuxEventBus.shared.publishSurfaceSelected(
                workspaceId: id,
                surfaceId: surfaceId,
                paneId: paneId.id,
                kind: kind,
                previousSurfaceId: previousSelectedSurfaceId,
                focused: true,
                origin: origin
            )
        }

        if HmuxSelectionEventState.focusedPaneByWorkspace[id] != paneId.id {
            HmuxSelectionEventState.focusedPaneByWorkspace[id] = paneId.id
            HmuxEventBus.shared.publishPaneFocused(
                workspaceId: id,
                paneId: paneId.id,
                selectedSurfaceId: surfaceId,
                origin: origin
            )
        }

        if HmuxSelectionEventState.focusedSurfaceByWorkspace[id] != surfaceId {
            HmuxSelectionEventState.focusedSurfaceByWorkspace[id] = surfaceId
            HmuxEventBus.shared.publishSurfaceFocused(
                workspaceId: id,
                surfaceId: surfaceId,
                paneId: paneId.id,
                kind: kind,
                origin: origin
            )
        }
    }

    static func hmuxEventSurfaceKind(_ panel: any Panel) -> String {
        switch panel.panelType {
        case .terminal:
            return "terminal"
        case .browser:
            return "browser"
        case .markdown:
            return "markdown"
        case .filePreview:
            return "file_preview"
        case .rightSidebarTool:
            return "right_sidebar_tool"
        case .customSidebar:
            return "custom_sidebar"
        case .simulator:
            return "simulator"
        case .agentSession:
            return "agent_session"
        case .project:
            return "project"
        case .extensionBrowser:
            return "extension_browser"
        case .workspaceTodo:
            return "workspace_todo"
        case .coderouterGuide:
            return "coderouter_guide"
        case .notifications:
            return "notifications"
        case .cloudVMLoading:
            return "cloud_vm_loading"
        case .mobilePairing:
            return "mobile_pairing"
        case .accountSignIn:
            return "account_sign_in"
        case .cloudVPNSetup:
            return "cloud_vpn_setup"
        case .chief:
            return "chief"
        }
    }
}

@MainActor
private enum MainWindowKeyRegainRefresh {
    static func refresh(window: NSWindow, context: AppDelegate.MainWindowContext) {
        // Window focus regain owns the redraw invariant. Cursor tracking and
        // focused subviews can update themselves only after this invalidation.
        invalidateContentDisplayTree(window: window)
        _ = context.keyboardFocusCoordinator.restoreTargetAfterWindowBecameKey()
    }

    private static func invalidateContentDisplayTree(window: NSWindow) {
        guard let contentView = window.contentView else { return }
        invalidateDisplayTree(rootedAt: contentView)
        window.invalidateCursorRects(for: contentView)
    }

    private static func invalidateDisplayTree(rootedAt view: NSView) {
        guard !view.isHidden else { return }
        view.needsDisplay = true
        view.layer?.setNeedsDisplay()
        for subview in view.subviews {
            invalidateDisplayTree(rootedAt: subview)
        }
    }
}

extension AppDelegate {
    func handleHmuxWindowBecameKey(_ note: Notification) {
        guard let window = note.object as? NSWindow else { return }
        MainActor.assumeIsolated {
            let context = senderRelativeMainWindowContext(for: window)
            setActiveMainWindow(window)
            if let windowId = mainWindowId(from: window) {
                publishHmuxWindowLifecycle(
                    name: "window.keyed",
                    windowId: windowId,
                    origin: "appkit_key",
                    exactWindow: window,
                    allowTeardownRoute: false
                )
            }
            if let context {
                MainWindowKeyRegainRefresh.refresh(window: window, context: context)
            }
        }
    }

    func handleHmuxWindowResignedKey(_ note: Notification) {
        guard let window = note.object as? NSWindow else { return }
        MainActor.assumeIsolated {
            if let windowId = mainWindowId(from: window) {
                publishHmuxWindowLifecycle(
                    name: "window.unkeyed",
                    windowId: windowId,
                    origin: "appkit_key",
                    exactWindow: window,
                    allowTeardownRoute: false
                )
            }
        }
    }

    func publishHmuxWindowLifecycle(
        name: String,
        windowId: UUID,
        origin: String,
        exactWindow: NSWindow? = nil,
        allowTeardownRoute: Bool = true
    ) {
        let manager: TabManager?
        if let exactWindow {
            manager = contextForMainTerminalWindow(exactWindow, reindex: false)?.tabManager
                ?? recoverableMainWindowIdentity(forExactWindow: exactWindow)?.tabManager
        } else if allowTeardownRoute {
            manager = tabManagerForWindowTeardown(windowId: windowId)
        } else {
            manager = tabManagerFor(windowId: windowId)
        }
        let workspaceId = manager?.selectedTabId
        let selectedWorkspaceIndex = workspaceId.flatMap { selectedId in
            manager?.tabs.firstIndex(where: { $0.id == selectedId })
        }
        let window = mainWindow(for: windowId)
        HmuxEventBus.shared.publishWindowLifecycle(
            name: name,
            windowId: windowId,
            workspaceId: workspaceId,
            workspaceCount: manager?.tabs.count,
            selectedWorkspaceIndex: selectedWorkspaceIndex,
            isKeyWindow: window?.isKeyWindow,
            isMainWindow: window?.isMainWindow,
            origin: origin
        )
    }
}
