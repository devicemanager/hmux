import Foundation
import Testing

@testable import HmuxSettings

@Suite struct SocketPathMarkerStoreTests {
    @Test func matchingMarkersAreClearedAcrossCurrentAndLegacyDirectories() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hmux-marker-store-\(UUID().uuidString)", isDirectory: true)
        let current = root.appendingPathComponent("state", isDirectory: true)
        let legacy = root.appendingPathComponent("legacy", isDirectory: true)
        let tmpMarkerPath = root.appendingPathComponent("tmp-marker").path
        defer { try? FileManager.default.removeItem(at: root) }

        let store = SocketPathMarkerStore(
            bundleIdentifier: SocketPathMarkerFiles.stableBundleIdentifier,
            environment: [:],
            stateDirectory: current,
            legacyDirectory: legacy,
            tmpMarkerPath: tmpMarkerPath
        )
        let socketPath = "/tmp/hmux-marker-store.sock"
        store.record(socketPath)
        #expect(store.markerPaths().allSatisfy { FileManager.default.fileExists(atPath: $0) })

        store.clearIfMatching(socketPath)

        #expect(store.markerPaths().allSatisfy { !FileManager.default.fileExists(atPath: $0) })
    }

    @Test func oversizedMarkerIsNeverLoadedOrRemoved() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hmux-marker-oversized-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let store = SocketPathMarkerStore(
            bundleIdentifier: SocketPathMarkerFiles.stableBundleIdentifier,
            environment: [:],
            stateDirectory: root,
            legacyDirectory: nil,
            tmpMarkerPath: root.appendingPathComponent("tmp-marker").path
        )
        let markerPath = try #require(store.markerPaths().first)
        let expectedPath = "/tmp/hmux-marker-oversized.sock"
        let oversized = expectedPath + String(
            repeating: " ",
            count: SocketPathMarkerStore.maximumMarkerBytes
        )
        try oversized.write(toFile: markerPath, atomically: true, encoding: .utf8)

        store.clearIfMatching(expectedPath)

        #expect(FileManager.default.fileExists(atPath: markerPath))
    }
}
