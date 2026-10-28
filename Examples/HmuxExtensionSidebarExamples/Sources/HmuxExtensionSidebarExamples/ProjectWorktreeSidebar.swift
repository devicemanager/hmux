import HmuxSidebarProviderKit
import Foundation

public struct ProjectWorktreeSidebar: HmuxSidebarProvider {
    public let descriptor = HmuxSidebarProviderDescriptor(
        id: "com.example.hmux.sidebar.project-worktrees",
        title: localized("example.sidebar.projectWorktrees.title", "Project Worktrees"),
        subtitle: localized("example.sidebar.projectWorktrees.subtitle", "User extension"),
        systemImageName: "folder",
        isHostProvided: false
    )

    public init() {}

    public func render(snapshot: HmuxSidebarProviderSnapshot) -> HmuxSidebarProviderRenderModel {
        var sections: [HmuxSidebarProviderSection] = []

        sections.append(
            ExampleSidebarSection(
                id: "pinned",
                title: localized("example.sidebar.group.pinned", "Pinned"),
                systemImageName: "pin",
                projectRootPath: nil,
                workspaces: snapshot.workspaces.filter(\.isPinned)
            )
            .render(subtitle: rowSubtitle)
        )

        var grouped: [String: [HmuxSidebarProviderWorkspace]] = [:]
        var orderedProjectRoots: [String] = []

        for workspace in snapshot.workspaces where !workspace.isPinned {
            let key = projectRoot(for: workspace) ?? "no-folder"
            if grouped[key] == nil {
                grouped[key] = []
                orderedProjectRoots.append(key)
            }
            grouped[key]?.append(workspace)
        }

        for root in orderedProjectRoots {
            let title = root == "no-folder" ? "No Folder" : displayName(for: root)
            let titleText = root == "no-folder"
                ? localized("example.sidebar.group.noFolder", "No Folder")
                : localized("example.sidebar.group.project", title)
            sections.append(
                ExampleSidebarSection(
                    id: "project:\(root)",
                    title: titleText,
                    systemImageName: root == "no-folder" ? "tray" : "folder",
                    projectRootPath: root == "no-folder" ? nil : root,
                    workspaces: grouped[root] ?? []
                )
                .render(subtitle: rowSubtitle)
            )
        }

        return renderModel(providerId: descriptor.id, snapshot: snapshot, sections: sections)
    }

    private func rowSubtitle(_ workspace: HmuxSidebarProviderWorkspace) -> HmuxSidebarProviderText? {
        if let description = trimmed(workspace.customDescription) {
            return .plain(description)
        }
        return trimmed(workspace.branchSummary).map(HmuxSidebarProviderText.plain)
    }
}
