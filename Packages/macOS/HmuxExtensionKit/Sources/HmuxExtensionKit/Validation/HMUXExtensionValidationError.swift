import Foundation

@_spi(HmuxHostTransport)
public enum HmuxExtensionValidationError: Error, Equatable, Sendable {
    case unsupportedAPIVersion(requested: HmuxExtensionAPIVersion, supported: HmuxExtensionAPIVersion)
    case emptyIdentifier
    case emptyDisplayName
    case payloadTooLarge(kind: String, actualBytes: Int, maximumBytes: Int)
}
