import HmuxExtensionKit
import Observation
import SwiftUI

@main
@Observable
final class TabsVisibleSidebarExtension: @MainActor HmuxSidebarExtension {
    static let manifest = HmuxExtensionManifest(
        id: "co.manaflow.TabsVisibleSidebar.Extension",
        displayName: String(localized: "tabsVisible.manifest.displayName", defaultValue: "Tabs Visible Sidebar"),
        readScopes: [
            .workspaceList,
            .workspaceMetadata,
            .surfaceMetadata,
        ],
        actionScopes: [
            .selectWorkspace,
            .selectSurface,
        ]
    )

    private(set) var snapshot: HmuxSidebarSnapshot?
    private(set) var errorText: String?
    var expandedWorkspaceIDs: Set<UUID> = []

    @ObservationIgnored
    private var host: HmuxSidebarHost?

    required init() {}

    var body: some View {
        TabsVisibleSidebarView(extensionModel: self)
    }

    func update(context: HmuxSidebarContext) {
        snapshot = context.snapshot
        host = context.host
        errorText = nil

        if let selectedWorkspaceID = context.snapshot.selectedWorkspaceID {
            expandedWorkspaceIDs.insert(selectedWorkspaceID)
        }
    }

    func connectionStatusDidChange(_ status: HmuxSidebarConnectionStatus) {
        switch status {
        case .connected:
            errorText = nil
        case .waitingForHost:
            errorText = String(localized: "tabsVisible.waitingForHost", defaultValue: "Waiting for hmux")
        case .error(let message):
            errorText = message
        }
    }

    func selectWorkspace(_ workspaceID: UUID) {
        guard let host else { return }
        expandedWorkspaceIDs.insert(workspaceID)
        Task { @MainActor in
            await apply { try await host.selectWorkspace(workspaceID) }
        }
    }

    func selectSurface(workspaceID: UUID, surfaceID: UUID) {
        guard let host else { return }
        expandedWorkspaceIDs.insert(workspaceID)
        Task { @MainActor in
            await apply { try await host.selectSurface(workspaceID: workspaceID, surfaceID: surfaceID) }
        }
    }

    private func apply(_ operation: () async throws -> Void) async {
        do {
            try await operation()
            errorText = nil
        } catch HmuxSidebarActionError.rejected(let message) {
            errorText = message
        } catch {
            errorText = String(localized: "tabsVisible.actionDenied", defaultValue: "hmux did not allow that action")
        }
    }
}
