import Foundation

/// Result returned after HMUX handles a provider mutation.
public struct HmuxSidebarProviderCommandResult: Codable, Equatable, Sendable {
    /// Whether HMUX accepted and completed the command.
    public var ok: Bool

    /// Creates a command result.
    public init(ok: Bool) {
        self.ok = ok
    }
}
