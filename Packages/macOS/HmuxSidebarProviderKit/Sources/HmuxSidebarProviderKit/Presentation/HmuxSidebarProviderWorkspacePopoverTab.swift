import Foundation

/// Tabs available when HMUX opens a workspace popover for a provider row.
public enum HmuxSidebarProviderWorkspacePopoverTab: String, Codable, CaseIterable, Equatable, Sendable {
    /// Notes tab.
    case notes
    /// Browser previews tab.
    case browser
    /// Pull request details tab.
    case pullRequest
}
