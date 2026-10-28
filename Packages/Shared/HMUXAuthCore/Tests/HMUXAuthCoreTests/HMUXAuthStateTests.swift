import HMUXAuthCore
import Foundation
import Testing

@Suite("HMUXAuthCore")
struct HMUXAuthStateTests {
    @Test("Config resolves development defaults and overrides")
    func configResolvesDevelopmentDefaultsAndOverrides() {
        let defaults = HMUXAuthConfig(
            environment: .development,
            developmentProjectId: "dev-project",
            productionProjectId: "prod-project",
            developmentPublishableClientKey: "dev-key",
            productionPublishableClientKey: "prod-key"
        )
        #expect(defaults == HMUXAuthConfig(projectId: "dev-project", publishableClientKey: "dev-key"))

        let overrides = HMUXAuthConfig(
            environment: .development,
            overrides: [
                "STACK_PROJECT_ID_DEV": "override-project",
                "STACK_PUBLISHABLE_CLIENT_KEY_DEV": "override-key",
            ],
            developmentProjectId: "dev-project",
            productionProjectId: "prod-project",
            developmentPublishableClientKey: "dev-key",
            productionPublishableClientKey: "prod-key"
        )
        #expect(overrides == HMUXAuthConfig(projectId: "override-project", publishableClientKey: "override-key"))
    }

    @Test("Config resolves production defaults and overrides")
    func configResolvesProductionDefaultsAndOverrides() {
        let defaults = HMUXAuthConfig(
            environment: .production,
            developmentProjectId: "dev-project",
            productionProjectId: "prod-project",
            developmentPublishableClientKey: "dev-key",
            productionPublishableClientKey: "prod-key"
        )
        #expect(defaults == HMUXAuthConfig(projectId: "prod-project", publishableClientKey: "prod-key"))

        let overrides = HMUXAuthConfig(
            environment: .production,
            overrides: [
                "STACK_PROJECT_ID_PROD": "override-project",
                "STACK_PUBLISHABLE_CLIENT_KEY_PROD": "override-key",
            ],
            developmentProjectId: "dev-project",
            productionProjectId: "prod-project",
            developmentPublishableClientKey: "dev-key",
            productionPublishableClientKey: "prod-key"
        )
        #expect(overrides == HMUXAuthConfig(projectId: "override-project", publishableClientKey: "override-key"))
    }

    @Test("Launch config returns credentials only when enabled")
    func launchConfigReturnsCredentialsOnlyWhenEnabled() {
        let environment = [
            "HMUX_UITEST_STACK_EMAIL": "test@example.com",
            "HMUX_UITEST_STACK_PASSWORD": "pass123",
        ]

        #expect(
            HMUXAuthAutoLoginCredentials(
                environment: environment,
                clearAuth: false,
                mockDataEnabled: false
            ) == HMUXAuthAutoLoginCredentials(email: "test@example.com", password: "pass123")
        )
        #expect(
            HMUXAuthAutoLoginCredentials(
                environment: environment,
                clearAuth: true,
                mockDataEnabled: false
            ) == nil
        )
        #expect(
            HMUXAuthAutoLoginCredentials(
                environment: environment,
                clearAuth: false,
                mockDataEnabled: true
            ) == nil
        )
    }

    @Test("Launch config returns fixture user only when enabled")
    func launchConfigReturnsFixtureUserOnlyWhenEnabled() {
        let environment = [
            "HMUX_UITEST_AUTH_FIXTURE": "1",
            "HMUX_UITEST_AUTH_USER_ID": "fixture-user",
            "HMUX_UITEST_AUTH_EMAIL": "fixture@example.com",
            "HMUX_UITEST_AUTH_NAME": "Fixture User",
            "HMUX_UITEST_AUTH_PROFILE_IMAGE_URL": "https://example.com/fixture-avatar.png",
        ]

        #expect(
            HMUXAuthUser(
                uiTestFixtureEnvironment: environment,
                clearAuth: false,
                mockDataEnabled: false
            ) == HMUXAuthUser(
                id: "fixture-user",
                primaryEmail: "fixture@example.com",
                displayName: "Fixture User",
                profileImageURL: "https://example.com/fixture-avatar.png"
            )
        )
        #expect(
            HMUXAuthUser(
                uiTestFixtureEnvironment: environment,
                clearAuth: true,
                mockDataEnabled: false
            ) == nil
        )
        #expect(
            HMUXAuthUser(
                uiTestFixtureEnvironment: environment,
                clearAuth: false,
                mockDataEnabled: true
            ) == nil
        )
    }

    @Test("Primed cached user remains restoring while validating tokens")
    func primedCachedUserRemainsRestoringWhileValidatingTokens() {
        let user = HMUXAuthUser(
            id: "user_123",
            primaryEmail: "user@example.com",
            displayName: "Test User",
            profileImageURL: "https://example.com/avatar.png"
        )
        let state = HMUXAuthState.primed(
            clearAuthRequested: false,
            mockDataEnabled: false,
            fixtureUser: nil,
            autoLoginCredentials: nil,
            cachedUser: user,
            hasTokens: true,
            mockUser: HMUXAuthUser(id: "mock", primaryEmail: "mock@example.com", displayName: "Mock")
        )

        #expect(state.isAuthenticated)
        #expect(state.currentUser == user)
        #expect(state.isRestoringSession)
    }

    @Test("Primed state restores when tokens exist without a cached user")
    func primedStateRestoresWhenTokensExistWithoutCachedUser() {
        let state = HMUXAuthState.primed(
            clearAuthRequested: false,
            mockDataEnabled: false,
            fixtureUser: nil,
            autoLoginCredentials: nil,
            cachedUser: nil,
            hasTokens: true,
            mockUser: HMUXAuthUser(id: "mock", primaryEmail: "mock@example.com", displayName: "Mock")
        )

        #expect(!state.isAuthenticated)
        #expect(state.currentUser == nil)
        #expect(state.isRestoringSession)
    }

    @Test("Primed state does not authenticate from auto-login credentials before sign-in")
    func primedStateDoesNotAuthenticateFromAutoLoginCredentialsBeforeSignIn() {
        let user = HMUXAuthUser(id: "user_123", primaryEmail: "user@example.com", displayName: "Test User")
        let state = HMUXAuthState.primed(
            clearAuthRequested: false,
            mockDataEnabled: false,
            fixtureUser: nil,
            autoLoginCredentials: HMUXAuthAutoLoginCredentials(email: "user@example.com", password: "password"),
            cachedUser: user,
            hasTokens: false,
            mockUser: HMUXAuthUser(id: "mock", primaryEmail: "mock@example.com", displayName: "Mock")
        )

        #expect(!state.isAuthenticated)
        #expect(state.currentUser == user)
        #expect(state.isRestoringSession)
    }

    @Test("Primed state ignores auto-login credentials when cached tokens exist")
    func primedStateIgnoresAutoLoginCredentialsWhenCachedTokensExist() {
        let user = HMUXAuthUser(id: "user_123", primaryEmail: "user@example.com", displayName: "Test User")
        let state = HMUXAuthState.primed(
            clearAuthRequested: false,
            mockDataEnabled: false,
            fixtureUser: nil,
            autoLoginCredentials: HMUXAuthAutoLoginCredentials(email: "user@example.com", password: "password"),
            cachedUser: user,
            hasTokens: true,
            mockUser: HMUXAuthUser(id: "mock", primaryEmail: "mock@example.com", displayName: "Mock")
        )

        #expect(state.isAuthenticated)
        #expect(state.currentUser == user)
        #expect(state.isRestoringSession)
    }

    @Test("Primed state does not authenticate from cached user alone")
    func primedStateDoesNotAuthenticateFromCachedUserAlone() {
        let user = HMUXAuthUser(id: "user_123", primaryEmail: "user@example.com", displayName: "Test User")
        let state = HMUXAuthState.primed(
            clearAuthRequested: false,
            mockDataEnabled: false,
            fixtureUser: nil,
            autoLoginCredentials: nil,
            cachedUser: user,
            hasTokens: false,
            mockUser: HMUXAuthUser(id: "mock", primaryEmail: "mock@example.com", displayName: "Mock")
        )

        #expect(!state.isAuthenticated)
        #expect(state.currentUser == user)
        #expect(!state.isRestoringSession)
    }

    @Test("Primed state uses fixture user")
    func primedStateUsesFixtureUser() {
        let fixtureUser = HMUXAuthUser(id: "fixture", primaryEmail: "fixture@example.com", displayName: "Fixture")
        let state = HMUXAuthState.primed(
            clearAuthRequested: false,
            mockDataEnabled: false,
            fixtureUser: fixtureUser,
            autoLoginCredentials: nil,
            cachedUser: nil,
            hasTokens: false,
            mockUser: HMUXAuthUser(id: "mock", primaryEmail: "mock@example.com", displayName: "Mock")
        )

        #expect(state.isAuthenticated)
        #expect(state.currentUser == fixtureUser)
        #expect(!state.isRestoringSession)
    }

    @Test("Cleared state clears auth")
    func clearedStateClearsAuth() {
        #expect(HMUXAuthState.cleared() == HMUXAuthState(isAuthenticated: false, currentUser: nil, isRestoringSession: false))
    }

    @Test("Identity store and session cache round trip")
    func identityStoreAndSessionCacheRoundTrip() throws {
        let store = TestKeyValueStore()
        let identityStore = HMUXAuthIdentityStore(keyValueStore: store, key: "auth_cached_user")
        let sessionCache = HMUXAuthSessionCache(keyValueStore: store, key: "auth_has_tokens")
        let user = HMUXAuthUser(id: "user_123", primaryEmail: "user@example.com", displayName: "Test User")

        try identityStore.save(user)
        #expect(try identityStore.load() == user)

        sessionCache.setHasTokens(true)
        #expect(sessionCache.hasTokens)

        identityStore.clear()
        sessionCache.clear()

        #expect(try identityStore.load() == nil)
        #expect(!sessionCache.hasTokens)
    }
}

private final class TestKeyValueStore: HMUXAuthKeyValueStore {
    private var storage: [String: Any] = [:]

    func bool(forKey defaultName: String) -> Bool {
        storage[defaultName] as? Bool ?? false
    }

    func data(forKey defaultName: String) -> Data? {
        storage[defaultName] as? Data
    }

    func string(forKey defaultName: String) -> String? {
        storage[defaultName] as? String
    }

    func set(_ value: Any?, forKey defaultName: String) {
        storage[defaultName] = value
    }

    func removeObject(forKey defaultName: String) {
        storage.removeValue(forKey: defaultName)
    }
}
