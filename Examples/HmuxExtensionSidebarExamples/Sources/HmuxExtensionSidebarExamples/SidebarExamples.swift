import HmuxSidebarProviderKit
import Foundation

public enum SidebarExamples {
    public static let providers: [any HmuxSidebarProvider] = [
        ProjectWorktreeSidebar(),
        AttentionQueueSidebar(),
        DevServerSidebar(),
        LastPromptSidebar(),
        SuperCompactSidebar(),
        BrowserStackSidebar(onAsyncStateLoaded: {
            BrowserStackSidebar.postStateDidLoadNotification()
        }),
    ]
}

struct ExampleSidebarSection {
    var id: String
    var title: HmuxSidebarProviderLocalizedText
    var systemImageName: String
    var projectRootPath: String?
    var workspaces: [HmuxSidebarProviderWorkspace]

    func render(
        rowTitle: (HmuxSidebarProviderWorkspace) -> String = { $0.title },
        accessory: HmuxSidebarProviderRowAccessory? = .inspector,
        subtitle: (HmuxSidebarProviderWorkspace) -> HmuxSidebarProviderText? = { _ in nil },
        trailingText: (HmuxSidebarProviderWorkspace) -> HmuxSidebarProviderText? = { _ in nil },
        leadingIcon: (HmuxSidebarProviderWorkspace) -> HmuxSidebarProviderIcon? = { _ in nil }
    ) -> HmuxSidebarProviderSection {
        HmuxSidebarProviderSection(
            id: id,
            treeSection: HmuxSidebarProviderTreeSection(
                id: id,
                title: title.defaultValue,
                titleText: title,
                subtitle: nil,
                systemImageName: systemImageName,
                projectRootPath: projectRootPath,
                workspaceIds: workspaces.map(\.id)
            ),
            rows: workspaces.map { workspace in
                HmuxSidebarProviderRow(
                    id: workspace.id,
                    title: rowTitle(workspace),
                    workspaceId: workspace.id,
                    accessory: accessory,
                    subtitle: subtitle(workspace),
                    trailingText: trailingText(workspace),
                    leadingIcon: leadingIcon(workspace)
                )
            }
        )
    }
}

func localized(_ key: String, _ defaultValue: String) -> HmuxSidebarProviderLocalizedText {
    HmuxSidebarProviderLocalizedText(key: key, defaultValue: defaultValue)
}

func renderModel(
    providerId: String,
    snapshot: HmuxSidebarProviderSnapshot,
    sections: [HmuxSidebarProviderSection],
    presentation: HmuxSidebarProviderPresentation = .tree
) -> HmuxSidebarProviderRenderModel {
    HmuxSidebarProviderRenderModel(
        providerId: providerId,
        snapshotSequence: snapshot.sequence,
        sections: presentation == .browserStack ? sections : sections.filter { !$0.rows.isEmpty },
        presentation: presentation
    )
}

func trimmed(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
          !trimmed.isEmpty else {
        return nil
    }
    return trimmed
}

func projectRoot(for workspace: HmuxSidebarProviderWorkspace) -> String? {
    trimmed(workspace.projectRootPath)
}

func displayName(for path: String) -> String {
    let url = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
    let name = url.lastPathComponent
    return name.isEmpty ? path : name
}
