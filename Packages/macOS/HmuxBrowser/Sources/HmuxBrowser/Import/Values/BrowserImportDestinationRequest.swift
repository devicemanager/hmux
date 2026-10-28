public import Foundation

/// A request for the hmux destination profile an import entry should write to.
public enum BrowserImportDestinationRequest: Equatable, Sendable {
    /// Import into the existing hmux profile with this identifier.
    case existing(UUID)
    /// Create a new hmux profile with this display name, then import into it.
    case createNamed(String)
}
