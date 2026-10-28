import Foundation

/// Validates a sidebar extension manifest before HMUX trusts it.
@_spi(HmuxHostTransport)
public func validateSidebarManifest(
    _ manifest: HmuxExtensionManifest,
    supportedAPIVersion: HmuxExtensionAPIVersion = .sidebarV2
) throws {
    guard manifest.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
        throw HmuxExtensionValidationError.emptyIdentifier
    }
    guard manifest.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
        throw HmuxExtensionValidationError.emptyDisplayName
    }
    guard manifest.minimumAPIVersion.major == supportedAPIVersion.major,
          manifest.minimumAPIVersion <= supportedAPIVersion else {
        throw HmuxExtensionValidationError.unsupportedAPIVersion(
            requested: manifest.minimumAPIVersion,
            supported: supportedAPIVersion
        )
    }
}
