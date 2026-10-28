import Foundation

/// Stable metadata HMUX uses to identify and present an in-process sidebar provider.
public struct HmuxSidebarProviderDescriptor: Identifiable, Codable, Equatable, Sendable {
    /// Provider id for the built-in workspace sidebar.
    public static let defaultWorkspacesID = "hmux.sidebar.default"

    /// Stable provider identifier persisted in user selection state.
    public var id: String
    /// Localized provider title shown in sidebar provider menus.
    public var title: HmuxSidebarProviderLocalizedText
    /// Optional localized detail text shown under the provider title.
    public var subtitle: HmuxSidebarProviderLocalizedText?
    /// SF Symbols name used for this provider in menus.
    public var systemImageName: String
    /// Whether the provider is supplied by HMUX rather than a package example.
    public var isHostProvided: Bool

    /// Creates sidebar provider metadata.
    public init(
        id: String,
        title: HmuxSidebarProviderLocalizedText,
        subtitle: HmuxSidebarProviderLocalizedText? = nil,
        systemImageName: String,
        isHostProvided: Bool
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.systemImageName = systemImageName
        self.isHostProvided = isHostProvided
    }

    /// Descriptor for HMUX's built-in workspace sidebar.
    public static let defaultWorkspaces = HmuxSidebarProviderDescriptor(
        id: defaultWorkspacesID,
        title: HmuxSidebarProviderLocalizedText(key: "sidebar.provider.default.title", defaultValue: "Default Workspaces"),
        subtitle: HmuxSidebarProviderLocalizedText(key: "sidebar.provider.default.subtitle", defaultValue: "hmux"),
        systemImageName: "list.bullet",
        isHostProvided: true
    )
}
