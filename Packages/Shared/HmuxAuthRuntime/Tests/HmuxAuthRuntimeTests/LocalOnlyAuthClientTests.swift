import HMUXAuthCore
import Foundation
import Testing
@testable import HmuxAuthRuntime

/// A local-only build must come up signed in as its fixed identity without a
/// sign-in screen, and must refuse every real account flow.
@MainActor
@Suite struct LocalOnlyAuthClientTests {
    @Test(.timeLimit(.minutes(1)))
    func restoresTheFixedLocalIdentityAtLaunch() async {
        let store = FakeKeyValueStore()
        let coordinator = AuthCoordinator(
            client: LocalOnlyAuthClient(),
            sessionCache: HMUXAuthSessionCache(keyValueStore: store, key: "has_tokens"),
            userCache: HMUXAuthIdentityStore(keyValueStore: store, key: "cached_user"),
            teamSelection: HMUXAuthTeamSelectionStore(keyValueStore: store, key: "selected_team"),
            anchor: FakeAnchor(),
            config: .test,
            launch: .plain()
        )
        coordinator.start()
        await coordinator.awaitBootstrapped()

        #expect(coordinator.isAuthenticated)
        #expect(coordinator.currentUser?.id == LocalOnlyAuthClient.user.id)
    }

    @Test func refusesAccountSignIn() async {
        await #expect(throws: AuthClientError.unsupported) {
            try await LocalOnlyAuthClient().signInWithCredential(email: "a@b.c", password: "x")
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func signOutKeepsTheLocalIdentity() async {
        let store = FakeKeyValueStore()
        let coordinator = AuthCoordinator(
            client: LocalOnlyAuthClient(),
            sessionCache: HMUXAuthSessionCache(keyValueStore: store, key: "has_tokens"),
            userCache: HMUXAuthIdentityStore(keyValueStore: store, key: "cached_user"),
            teamSelection: HMUXAuthTeamSelectionStore(keyValueStore: store, key: "selected_team"),
            anchor: FakeAnchor(),
            config: .test,
            launch: .plain()
        )
        coordinator.start()
        await coordinator.awaitBootstrapped()
        await coordinator.signOut()

        #expect(coordinator.isAuthenticated)
        #expect(coordinator.isLocalOnlySession)
    }
}
