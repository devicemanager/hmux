import HmuxExtensionKit
import SwiftUI

@main
final class SampleSidebarExtension: @MainActor HmuxSidebarExtension {
    static let manifest = HmuxExtensionManifest(
        id: "co.manaflow.HMUXExtKitSampleSidebarApp.Extension",
        displayName: String(localized: "sampleSidebar.manifest.displayName", defaultValue: "HMUX Sample Sidebar Extension"),
        readScopes: [
            .workspaceList,
            .workspaceMetadata,
            .surfaceMetadata,
            .notifications,
            .networkPorts,
            .pullRequests,
        ],
        actionScopes: [
            .createSurface,
            .selectWorkspace,
            .selectSurface,
            .navigateWorkspace,
            .navigateSurface,
        ]
    )

    private let model = SidebarConnectionModel()

    required init() {}

    var body: some View {
        SampleSidebarView(model: model)
    }

    func update(context: HmuxSidebarContext) {
        model.update(context: context)
    }

    func connectionStatusDidChange(_ status: HmuxSidebarConnectionStatus) {
        model.connectionStatusDidChange(status)
    }
}
