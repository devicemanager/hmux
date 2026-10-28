public import HMUXAuthCore
import Foundation

/// The ``AuthClient`` for a local-only build: one fixed on-device identity and
/// no network calls.
///
/// A local-only phone authorizes to its Macs with per-device keys from
/// `CmxLocalPairing`, never with an account. The coordinator still drives the
/// app's signed-in state, so this client reports a permanent session for a
/// single local user and team, and refuses every sign-in or account flow.
public struct LocalOnlyAuthClient: AuthClient {
    /// The fixed identity. Stable across launches so per-account local state
    /// (paired Macs, Tailscale grants) survives restarts.
    public static let user = HMUXAuthUser(
        id: "local-only-user",
        primaryEmail: nil,
        displayName: "This iPhone"
    )
    public static let team = HMUXAuthTeam(id: "local-only-team", displayName: "Local")
    /// Placeholder session token. It is never a credential: local routes send
    /// device keys, and nothing in a local-only build contacts an account API.
    static let sessionToken = "local-only-session"

    public init() {}

    public func accessToken() async -> String? { Self.sessionToken }
    public func resolvedAccessToken(forceRefresh: Bool) async throws -> String? { Self.sessionToken }
    public func refreshToken() async -> String? { Self.sessionToken }
    public func forceRefreshAccessToken() async -> String? { Self.sessionToken }
    public func storedAccessToken() async -> String? { Self.sessionToken }
    public func freshAccessToken(accessToken: String?, refreshToken: String) async -> String? { Self.sessionToken }

    public func currentUser(throwOnMissing: Bool) async throws -> HMUXAuthUser? { Self.user }
    public func listTeams() async throws -> [HMUXAuthTeam] { [Self.team] }
    public func selectedTeamID() async throws -> String? { Self.team.id }
    public func setSelectedTeam(id: String?) async throws {}

    public func createTeam(displayName: String) async throws -> HMUXAuthTeam {
        throw AuthClientError.unsupported
    }

    public func sendMagicLinkEmail(email: String, callbackURL: String) async throws -> String {
        throw AuthClientError.unsupported
    }

    public func signInWithMagicLink(code: String) async throws {
        throw AuthClientError.unsupported
    }

    public func signInWithCredential(email: String, password: String) async throws {
        throw AuthClientError.unsupported
    }

    public func signInWithOAuth(provider: String, anchor: any AuthPresentationAnchoring) async throws {
        throw AuthClientError.unsupported
    }

    public func clearLocalSession() async {}
    public func clearLocalSession(ifRefreshTokenMatches refreshToken: String) async {}
    public func revokeSession(accessToken: String?, refreshToken: String?) async throws {}
}
