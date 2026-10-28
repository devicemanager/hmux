import Foundation

/// Row rendered inside a provider section.
public struct HmuxSidebarProviderRow: Identifiable, Codable, Equatable, Sendable {
    /// Stable row id.
    public var id: UUID
    /// Primary row title.
    public var title: String
    /// Workspace represented by the row.
    public var workspaceId: UUID
    /// Optional trailing accessory.
    public var accessory: HmuxSidebarProviderRowAccessory?
    /// Optional subtitle.
    public var subtitle: HmuxSidebarProviderText?
    /// Optional trailing text.
    public var trailingText: HmuxSidebarProviderText?
    /// Optional leading icon.
    public var leadingIcon: HmuxSidebarProviderIcon?

    /// Creates a provider row.
    public init(
        id: UUID,
        title: String,
        workspaceId: UUID,
        accessory: HmuxSidebarProviderRowAccessory?,
        subtitle: HmuxSidebarProviderText? = nil,
        trailingText: HmuxSidebarProviderText? = nil,
        leadingIcon: HmuxSidebarProviderIcon? = nil
    ) {
        self.id = id
        self.title = title
        self.workspaceId = workspaceId
        self.accessory = accessory
        self.subtitle = subtitle
        self.trailingText = trailingText
        self.leadingIcon = leadingIcon
    }
}
