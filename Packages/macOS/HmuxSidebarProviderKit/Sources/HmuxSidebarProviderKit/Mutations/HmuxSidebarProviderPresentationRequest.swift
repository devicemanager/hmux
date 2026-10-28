import Foundation

/// Presentation command a provider can request from the HMUX sidebar host.
public enum HmuxSidebarProviderPresentationRequest: Codable, Equatable, Sendable {
    /// Open the workspace popover on a preferred tab.
    case openWorkspacePopover(workspaceId: UUID, preferredTab: HmuxSidebarProviderWorkspacePopoverTab)
    /// Open a detached workspace window on a preferred tab.
    case openWorkspaceWindow(workspaceId: UUID, preferredTab: HmuxSidebarProviderWorkspacePopoverTab)
    /// Ask HMUX to open a URL.
    case openURL(String)
}
