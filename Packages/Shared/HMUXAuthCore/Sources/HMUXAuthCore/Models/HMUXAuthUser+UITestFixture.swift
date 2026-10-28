import Foundation

extension HMUXAuthUser {
    /// Parse a UI-test fixture user from the launch environment, or `nil`
    /// when no fixture was requested.
    ///
    /// UI tests opt in with `HMUX_UITEST_AUTH_FIXTURE=1` and may override the
    /// id/email/name/profile-image fields; a cleared-auth or mock-data launch
    /// always wins over a fixture.
    /// - Parameters:
    ///   - environment: The process launch environment.
    ///   - clearAuth: Whether the launch requested a cleared auth state.
    ///   - mockDataEnabled: Whether mock-data mode is active.
    public init?(
        uiTestFixtureEnvironment environment: [String: String],
        clearAuth: Bool,
        mockDataEnabled: Bool
    ) {
        if clearAuth || mockDataEnabled {
            return nil
        }
        guard environment["HMUX_UITEST_AUTH_FIXTURE"] == "1" else {
            return nil
        }
        self.init(
            id: environment["HMUX_UITEST_AUTH_USER_ID"] ?? "uitest_user",
            primaryEmail: environment["HMUX_UITEST_AUTH_EMAIL"] ?? "uitest@hmux.local",
            displayName: environment["HMUX_UITEST_AUTH_NAME"] ?? "UI Test",
            profileImageURL: environment["HMUX_UITEST_AUTH_PROFILE_IMAGE_URL"]
        )
    }
}
