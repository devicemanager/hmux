/// Errors surfaced by ``HmuxAPIClient`` when a request does not return the
/// documented success response.
public enum HmuxAPIError: Error, Sendable, Equatable {
    /// The server rejected the request as unauthenticated (HTTP 401).
    case unauthorized
    /// The server returned a status the client does not model.
    case unexpectedStatus
}
