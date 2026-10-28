import Bonsplit
import Foundation
import Testing

#if canImport(hmux_DEV)
@testable import hmux_DEV
#elseif canImport(hmux)
@testable import hmux
#endif

@MainActor
@Suite(.serialized) struct WorkspaceCustomLayoutOrderTests {
    @Test(arguments: [0, 1, 2, 3])
    func allTerminalSurfacesPreserveDeclaredOrder(focusedIndex: Int) throws {
        let names = ["AAA", "BBB", "CCC", "DDD"]
        let surfaces = names.enumerated().map { index, name in
            HmuxSurfaceDefinition(type: .terminal, name: name, focus: index == focusedIndex)
        }

        let workspace = Workspace()
        workspace.applyCustomLayout(
            .pane(HmuxPaneDefinition(surfaces: surfaces)),
            baseCwd: NSTemporaryDirectory()
        )

        let snapshot = try Self.surfaceSnapshot(in: workspace)
        #expect(snapshot.titles == names)
        #expect(snapshot.selectedTitle == names[focusedIndex])
    }

    @Test(arguments: [0, 1, 2])
    func mixedTerminalAndBrowserSurfacesPreserveDeclaredOrder(focusedIndex: Int) throws {
        let names = ["Docs", "Shell", "Logs"]
        let surfaces = [
            HmuxSurfaceDefinition(
                type: .browser,
                name: names[0],
                url: nil,
                focus: focusedIndex == 0
            ),
            HmuxSurfaceDefinition(type: .terminal, name: names[1], focus: focusedIndex == 1),
            HmuxSurfaceDefinition(type: .terminal, name: names[2], focus: focusedIndex == 2),
        ]

        let workspace = Workspace()
        workspace.applyCustomLayout(
            .pane(HmuxPaneDefinition(surfaces: surfaces)),
            baseCwd: NSTemporaryDirectory()
        )

        let snapshot = try Self.surfaceSnapshot(in: workspace)
        #expect(snapshot.titles == names)
        #expect(snapshot.selectedTitle == names[focusedIndex])
    }

    @Test(arguments: [NewTabPosition.current, .end])
    func layoutApplicationRestoresInteractiveNewTabPlacement(initialPlacement: NewTabPosition) throws {
        let workspace = Workspace()
        workspace.bonsplitController.configuration.newTabPosition = initialPlacement
        workspace.applyCustomLayout(
            .pane(HmuxPaneDefinition(surfaces: [
                HmuxSurfaceDefinition(type: .terminal, name: "AAA"),
                HmuxSurfaceDefinition(type: .terminal, name: "BBB", focus: true),
                HmuxSurfaceDefinition(type: .terminal, name: "CCC"),
            ])),
            baseCwd: NSTemporaryDirectory()
        )

        let paneId = try #require(workspace.bonsplitController.allPaneIds.first)
        let layoutTabIds = workspace.bonsplitController.tabs(inPane: paneId).map(\.id)
        try #require(layoutTabIds.count == 3)

        switch (initialPlacement, workspace.bonsplitController.configuration.newTabPosition) {
        case (.current, .current), (.end, .end):
            break
        default:
            Issue.record("Layout application did not restore the initial new-tab placement")
        }

        let newPanel = try #require(workspace.newTerminalSurface(inPane: paneId, focus: false))
        let newTabId = try #require(workspace.surfaceIdFromPanelId(newPanel.id))
        let expectedTabIds: [TabID]
        switch initialPlacement {
        case .current:
            expectedTabIds = [layoutTabIds[0], layoutTabIds[1], newTabId, layoutTabIds[2]]
        case .end:
            expectedTabIds = [layoutTabIds[0], layoutTabIds[1], layoutTabIds[2], newTabId]
        }

        #expect(workspace.bonsplitController.tabs(inPane: paneId).map(\.id) == expectedTabIds)
        #expect(workspace.bonsplitController.selectedTab(inPane: paneId)?.id == layoutTabIds[1])
    }

    private static func surfaceSnapshot(in workspace: Workspace) throws -> (titles: [String], selectedTitle: String?) {
        let paneId = try #require(workspace.bonsplitController.allPaneIds.first)
        let titles = workspace.bonsplitController.tabs(inPane: paneId).map(\.title)
        let selectedTitle = workspace.bonsplitController.selectedTab(inPane: paneId)?.title
        return (titles, selectedTitle)
    }
}
