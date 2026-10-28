import Foundation

/// Metadata and permission request declared by a HMUX extension.
public struct HmuxExtensionManifest: Codable, Equatable, Identifiable, Sendable {
    /// Stable reverse-DNS style identifier for the extension.
    public var id: String

    /// Human-readable extension name shown by HMUX permission and management UI.
    public var displayName: String

    /// Minimum HMUX extension API version required by this extension.
    @_spi(HmuxHostTransport) public var minimumAPIVersion: HmuxExtensionAPIVersion

    /// Sidebar data scopes the extension asks HMUX to include in snapshots.
    public var readScopes: [HmuxExtensionScope]

    /// Host action scopes the extension asks HMUX to allow.
    public var actionScopes: [HmuxExtensionActionScope]

    /// Creates a sidebar extension manifest.
    public init(
        id: String,
        displayName: String,
        readScopes: [HmuxExtensionScope] = [],
        actionScopes: [HmuxExtensionActionScope] = []
    ) {
        self.id = id
        self.displayName = displayName
        self.minimumAPIVersion = .sidebarV2
        self.readScopes = readScopes
        self.actionScopes = actionScopes
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case minimumAPIVersion
        case readScopes
        case actionScopes
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        minimumAPIVersion = try container.decodeIfPresent(HmuxExtensionAPIVersion.self, forKey: .minimumAPIVersion) ?? .sidebarV2
        readScopes = try container.decode([HmuxExtensionScope].self, forKey: .readScopes)
        actionScopes = try container.decodeIfPresent(
            [HmuxExtensionActionScope].self,
            forKey: .actionScopes
        ) ?? []
    }
}
