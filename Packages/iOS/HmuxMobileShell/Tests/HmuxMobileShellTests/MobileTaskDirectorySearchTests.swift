import Testing
import HmuxMobileRPC
@testable import HmuxMobileShell

@MainActor
@Suite struct MobileTaskDirectorySearchTests {
    @Test func liveSearchDoesNotTrustStaleMissingCapabilityMetadata() async throws {
        let router = RoutingHostRouter()
        let store = try await makeRoutingConnectedStore(
            router: router,
            hostCapabilities: []
        )

        let result = await store.searchTaskDirectories(
            macDeviceID: "test-mac",
            query: "  hmux  "
        )

        #expect(await router.recordedDirectorySearchQueries() == ["hmux"])
        #expect(
            result == .success(MobileTaskDirectorySearchResponse(
                directories: [
                    "/Users/test/Dev/Manaflow/hmux",
                    "/Users/test/Dev/Manaflow/hmuxterm-hq",
                ]
            ))
        )
    }

    @Test func liveSearchSurfacesTimeoutForRetry() async throws {
        let router = RoutingHostRouter()
        await router.setDirectorySearchError(
            code: "request_timeout",
            message: "Directory search timed out"
        )
        let store = try await makeRoutingConnectedStore(router: router)

        let result = await store.searchTaskDirectories(macDeviceID: "test-mac", query: "hmux")

        #expect(result == .failure(.timedOut))
    }

    @Test func olderHostWithoutSearchMethodSurfacesUnsupportedSearch() async throws {
        let router = RoutingHostRouter()
        await router.setDirectorySearchError(code: "method_not_found", message: "Unknown method")
        let store = try await makeRoutingConnectedStore(router: router)

        let result = await store.searchTaskDirectories(macDeviceID: "test-mac", query: "hmux")

        #expect(result == .failure(.unsupported))
    }
}
