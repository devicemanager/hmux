import Foundation

@_spi(HmuxHostTransport)
/// Result returned by HMUX for a sidebar host action request.
public struct HmuxSidebarActionResult: Codable, Equatable, Sendable {
    /// Whether HMUX accepted and applied the action.
    public var accepted: Bool

    /// Optional host-supplied result or rejection message.
    public var message: String?

    /// Structured reason when the action was rejected.
    public var rejectionReason: HmuxSidebarActionRejectionReason?

    /// Creates an action result.
    public init(
        accepted: Bool,
        message: String? = nil,
        rejectionReason: HmuxSidebarActionRejectionReason? = nil
    ) {
        self.accepted = accepted
        self.message = message
        self.rejectionReason = accepted ? nil : rejectionReason
    }

    /// Successful action result.
    public static let accepted = HmuxSidebarActionResult(accepted: true)

    /// Creates a rejected action result with a displayable message.
    public static func rejected(
        _ message: String,
        reason: HmuxSidebarActionRejectionReason = .rejected
    ) -> HmuxSidebarActionResult {
        HmuxSidebarActionResult(accepted: false, message: message, rejectionReason: reason)
    }

    /// Rejected action result used when the caller cancels an in-flight request.
    public static let cancelled = HmuxSidebarActionResult(
        accepted: false,
        message: "Extension action was cancelled",
        rejectionReason: .cancelled
    )
}

@_spi(HmuxHostTransport)
/// Machine-readable reason HMUX rejected a sidebar action.
public enum HmuxSidebarActionRejectionReason: String, Codable, Equatable, Sendable {
    /// Generic host rejection.
    case rejected

    /// The caller cancelled the action before the host completed it.
    case cancelled
}

/// Error thrown by typed `HmuxSidebarHost` action helpers.
public enum HmuxSidebarActionError: Error, Equatable, Sendable {
    /// HMUX rejected the action with a displayable message.
    case rejected(String)

    /// The caller cancelled the action before completion.
    case cancelled
}
