import Foundation
import Testing

#if canImport(hmux_DEV)
@testable import hmux_DEV
#elseif canImport(hmux)
@testable import hmux
#endif

@MainActor
@Suite(.serialized)
struct GlobalSearchInstanceIsolationTests {
    @Test
    func databaseURLsAreScopedByBundleIdentifier() {
        let applicationSupportDirectory = URL(
            fileURLWithPath: "/tmp/hmux-search-instance-isolation",
            isDirectory: true
        )

        let stableURL = URL.hmuxSearchDatabaseURL(
            applicationSupportDirectory: applicationSupportDirectory,
            bundleIdentifier: "com.hmuxterm.app"
        )
        let taggedURL = URL.hmuxSearchDatabaseURL(
            applicationSupportDirectory: applicationSupportDirectory,
            bundleIdentifier: "com.hmuxterm.app.debug.sym7440"
        )
        let unsafeURL = URL.hmuxSearchDatabaseURL(
            applicationSupportDirectory: applicationSupportDirectory,
            bundleIdentifier: "  com.hmuxterm.app/debug  "
        )

        #expect(stableURL != taggedURL)
        #expect(stableURL.path == "/tmp/hmux-search-instance-isolation/com.hmuxterm.app/search.db")
        #expect(taggedURL.path == "/tmp/hmux-search-instance-isolation/com.hmuxterm.app.debug.sym7440/search.db")
        #expect(unsafeURL.path == "/tmp/hmux-search-instance-isolation/com.hmuxterm.app_debug/search.db")
    }

    @Test
    func startingSecondBundleDoesNotClearFirstBundleIndex() async throws {
        let fixtureDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("hmux-search-instance-isolation-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: fixtureDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: fixtureDirectory) }

        let firstDatabaseURL = URL.hmuxSearchDatabaseURL(
            applicationSupportDirectory: fixtureDirectory,
            bundleIdentifier: "com.hmuxterm.app.debug.first"
        )
        let secondDatabaseURL = URL.hmuxSearchDatabaseURL(
            applicationSupportDirectory: fixtureDirectory,
            bundleIdentifier: "com.hmuxterm.app.debug.second"
        )

        let firstIndex = try SearchIndex(databaseURL: firstDatabaseURL)
        try await firstIndex.upsert(
            SearchIndexDocument(
                id: "first-instance-document",
                windowID: UUID(),
                workspaceID: UUID(),
                panelID: UUID(),
                kind: .markdown,
                title: "First Instance",
                location: "/tmp/first.md",
                anchor: "/tmp/first.md",
                text: "firstinstanceisolationtoken"
            )
        )
        let firstCoordinator = GlobalSearchCoordinator(databaseURL: firstDatabaseURL)
        #expect(await firstCoordinator.search(query: "firstinstanceisolationtoken").count == 1)

        let staleSecondIndex = try SearchIndex(databaseURL: secondDatabaseURL)
        try await staleSecondIndex.upsert(
            SearchIndexDocument(
                id: "stale-second-instance-document",
                windowID: UUID(),
                workspaceID: UUID(),
                panelID: UUID(),
                kind: .title,
                title: "Stale Second Instance",
                location: "Old Window",
                anchor: "title",
                text: "stalesecondinstanceindextoken"
            )
        )

        let secondCoordinator = GlobalSearchCoordinator(databaseURL: secondDatabaseURL)
        await secondCoordinator.start().value

        #expect(await firstCoordinator.search(query: "firstinstanceisolationtoken").count == 1)
        #expect(await secondCoordinator.search(query: "stalesecondinstanceindextoken").isEmpty)
    }
}
