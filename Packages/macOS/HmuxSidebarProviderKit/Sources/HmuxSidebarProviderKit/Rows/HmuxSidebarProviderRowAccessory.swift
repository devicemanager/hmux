import Foundation

/// Accessory control displayed at the trailing edge of a provider row.
public struct HmuxSidebarProviderRowAccessory: Codable, Equatable, Sendable {
    /// Accessory behavior.
    public var kind: HmuxSidebarProviderRowAccessoryKind
    /// SF Symbols name for the accessory icon.
    public var systemImageName: String
    /// Default popover tab when the accessory opens workspace details.
    public var defaultTab: HmuxSidebarProviderWorkspacePopoverTab

    /// Creates a row accessory.
    public init(
        kind: HmuxSidebarProviderRowAccessoryKind,
        systemImageName: String,
        defaultTab: HmuxSidebarProviderWorkspacePopoverTab
    ) {
        self.kind = kind
        self.systemImageName = systemImageName
        self.defaultTab = defaultTab
    }

    /// Standard workspace inspector accessory.
    public static let inspector = HmuxSidebarProviderRowAccessory(
        kind: .workspaceInspector,
        systemImageName: "ellipsis.circle",
        defaultTab: .notes
    )
}
