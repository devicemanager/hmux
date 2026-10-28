import HmuxSidebarProviderKit
import Foundation

public struct SuperCompactSidebar: HmuxSidebarProvider {
    public let descriptor = HmuxSidebarProviderDescriptor(
        id: "com.example.hmux.sidebar.super-compact",
        title: localized("example.sidebar.superCompact.title", "Super Compact"),
        subtitle: localized("example.sidebar.superCompact.subtitle", "User extension"),
        systemImageName: "rectangle.compress.vertical",
        isHostProvided: false
    )

    public init() {}

    public func render(snapshot: HmuxSidebarProviderSnapshot) -> HmuxSidebarProviderRenderModel {
        let ordered = snapshot.workspaces.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }

        let section = ExampleSidebarSection(
            id: "workspaces",
            title: localized("example.sidebar.group.workspaces", "Workspaces"),
            systemImageName: "list.bullet",
            projectRootPath: nil,
            workspaces: ordered
        )
        .render(
            rowTitle: compactTitle,
            accessory: nil,
            trailingText: unreadTrailingText
        )

        return renderModel(providerId: descriptor.id, snapshot: snapshot, sections: [section])
    }

    private func compactTitle(_ workspace: HmuxSidebarProviderWorkspace) -> String {
        if let projectRoot = projectRoot(for: workspace) {
            return displayName(for: projectRoot)
        }
        return workspace.title
    }

    private func unreadTrailingText(_ workspace: HmuxSidebarProviderWorkspace) -> HmuxSidebarProviderText? {
        workspace.unreadCount > 0 ? .plain("\(workspace.unreadCount)") : nil
    }
}
