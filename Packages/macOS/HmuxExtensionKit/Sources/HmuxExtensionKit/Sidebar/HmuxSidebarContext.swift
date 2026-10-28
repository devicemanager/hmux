import Foundation

/// Current sidebar state delivered by HMUX to a sidebar extension.
public struct HmuxSidebarContext: Sendable {
    /// Latest workspace snapshot filtered to the permissions granted by the user.
    public let snapshot: HmuxSidebarSnapshot

    /// Read scopes HMUX granted for this snapshot.
    public let grantedReadScopes: Set<HmuxExtensionScope>

    /// Host actions HMUX will currently accept from this extension.
    public let grantedActionScopes: Set<HmuxExtensionActionScope>

    /// Typed command channel back to HMUX.
    public let host: HmuxSidebarHost

    @MainActor
    public init(
        snapshot: HmuxSidebarSnapshot,
        grantedReadScopes: Set<HmuxExtensionScope>? = nil,
        grantedActionScopes: Set<HmuxExtensionActionScope>? = nil,
        host: HmuxSidebarHost
    ) {
        self.snapshot = snapshot
        self.grantedReadScopes = grantedReadScopes ?? snapshot.grantedReadScopes
        self.grantedActionScopes = grantedActionScopes ?? snapshot.grantedActionScopes
        self.host = host
    }
}
