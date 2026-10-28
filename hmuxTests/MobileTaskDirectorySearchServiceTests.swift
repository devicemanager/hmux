@testable import HmuxMobileHost
import Foundation
import Testing

#if canImport(hmux_DEV)
@testable import hmux_DEV
#elseif canImport(hmux)
@testable import hmux
#endif

@Suite struct MobileTaskDirectorySearchServiceTests {
    private static let inertWalk: MobileTaskDirectorySearchService.FilesystemWalkOperation = { _, _ in
        MobileTaskDirectoryFilesystemWalker.Outcome(
            matches: [],
            visitedDirectoryCount: 0,
            complete: false
        )
    }

    @Test func dispatchRejectsAnEmptyDirectoryQuery() async {
        #expect(MobileHostService.mobileHostCapabilities.contains("workspace.directory_search.v1"))
        #expect(MobileHostService.mobileHostCapabilities.contains("workspace.directory_search.v2"))

        let request = MobileHostRPCRequest(
            id: "directory-search",
            method: "mobile.directory.search",
            params: ["query": ""],
            auth: nil
        )

        let result = await TerminalController.shared.mobileHostHandleRPC(request)

        guard case let .failure(error) = result else {
            return #expect(Bool(false), "An empty directory query must be rejected")
        }
        #expect(error.code == "invalid_params")
    }

    @Test func ranksStrictAndComponentMatchesBeforeLenientMatches() {
        let paths = [
            "/Users/test/Dev/Manaflow/hmuxterm-hq",
            "/Users/test/Dev/Manaflow/cmixterm-hq",
            "/Users/test/Documents/hmux-notes",
        ]

        let strict = MobileTaskDirectorySearchService.rank(paths: paths, query: "hmux", limit: 8)
        #expect(strict.first == "/Users/test/Documents/hmux-notes")
        #expect(strict.contains("/Users/test/Dev/Manaflow/hmuxterm-hq"))

        let components = MobileTaskDirectorySearchService.rank(paths: paths, query: "mana cmu", limit: 8)
        #expect(components == ["/Users/test/Dev/Manaflow/hmuxterm-hq"])

        let fuzzy = MobileTaskDirectorySearchService.rank(paths: paths, query: "manaflw", limit: 8)
        #expect(fuzzy.prefix(2).contains("/Users/test/Dev/Manaflow/hmuxterm-hq"))
    }

    @MainActor
    @Test func metadataPredicateMatchesDirectoryTypeTreesAcrossPathTokens() {
        let predicate = MobileTaskDirectoryMetadataQueryRunner.makePredicate(query: "Manaflow hmux")

        #expect(predicate.evaluate(with: [
            NSMetadataItemContentTypeTreeKey: ["public.item", "public.directory"],
            NSMetadataItemFSNameKey: "hmuxterm-hq",
            NSMetadataItemPathKey: "/Users/test/Dev/Manaflow/hmuxterm-hq",
        ]))
        #expect(!predicate.evaluate(with: [
            NSMetadataItemContentTypeTreeKey: ["public.item", "public.data"],
            NSMetadataItemFSNameKey: "hmuxterm-hq",
            NSMetadataItemPathKey: "/Users/test/Dev/Manaflow/hmuxterm-hq",
        ]))
    }

    @Test func mergesContextualAndIndexedMatchesWithoutEarlyReturningOneExactPath() async throws {
        let service = MobileTaskDirectorySearchService(
            homeDirectory: URL(fileURLWithPath: "/Users/test", isDirectory: true),
            metadataSearchOperation: { _, _, _ in
                MobileTaskDirectoryMetadataQueryRunner.Snapshot(
                    paths: [
                        "/Users/test/Dev/hmux",
                        "/Volumes/External/hmux",
                    ],
                    gatheringComplete: true,
                    totalMatchCount: 2,
                    truncated: false
                )
            },
            directoryExists: { _ in true },
            filesystemWalkOperation: Self.inertWalk
        )

        let result = try await service.search(
            query: "hmux",
            seedPaths: ["/Users/test/Open/hmux"]
        )

        #expect(Set(result.directories) == Set([
            "/Users/test/Open/hmux",
            "/Users/test/Dev/hmux",
            "/Volumes/External/hmux",
        ]))
        #expect(result.scope == .allIndexedVolumes)
        #expect(result.gatheringComplete)
        #expect(!result.filesystemComplete)
        #expect(!result.truncated)
        #expect(result.indexedMatchCount == 2)
    }

    @Test func reportsPartialAndTruncatedIndexedCoverage() async throws {
        let service = MobileTaskDirectorySearchService(
            configuration: .init(maximumMetadataResults: 3, maximumWireResults: 2),
            metadataSearchOperation: { _, _, _ in
                MobileTaskDirectoryMetadataQueryRunner.Snapshot(
                    paths: [
                        "/Volumes/A/project",
                        "/Volumes/B/project",
                        "/Volumes/C/project",
                    ],
                    gatheringComplete: false,
                    totalMatchCount: 100,
                    truncated: true
                )
            },
            directoryExists: { _ in true },
            filesystemWalkOperation: Self.inertWalk
        )

        let result = try await service.search(query: "project", seedPaths: [])

        #expect(result.directories.count == 2)
        #expect(result.scope == .allIndexedVolumes)
        #expect(!result.gatheringComplete)
        #expect(!result.filesystemComplete)
        #expect(result.truncated)
        #expect(result.indexedMatchCount == 100)
    }

    @Test func metadataUnavailabilityFallsBackWithExplicitContextOnlyCoverage() async throws {
        let service = MobileTaskDirectorySearchService(
            homeDirectory: URL(fileURLWithPath: "/Users/test", isDirectory: true),
            metadataSearchOperation: { _, _, _ in
                throw MobileTaskDirectoryMetadataQueryRunner.QueryError.unavailable
            },
            directoryExists: { _ in true },
            filesystemWalkOperation: Self.inertWalk
        )

        let result = try await service.search(
            query: "project",
            seedPaths: ["/Users/test/Open/project"]
        )

        #expect(result.directories == ["/Users/test/Open/project"])
        #expect(result.scope == .contextualCandidatesOnly)
        #expect(!result.gatheringComplete)
        #expect(!result.filesystemComplete)
        #expect(!result.truncated)
        #expect(result.indexedMatchCount == 0)
    }

    @Test func concurrentClientsDoNotCancelEachOthersSearches() async {
        let service = MobileTaskDirectorySearchService(
            metadataSearchOperation: { query, _, _ in
                await Task.yield()
                return MobileTaskDirectoryMetadataQueryRunner.Snapshot(
                    paths: ["/Volumes/Projects/\(query)"],
                    gatheringComplete: true,
                    totalMatchCount: 1,
                    truncated: false
                )
            },
            directoryExists: { _ in true },
            filesystemWalkOperation: Self.inertWalk
        )

        let results = await withTaskGroup(
            of: MobileTaskDirectorySearchResult?.self,
            returning: [MobileTaskDirectorySearchResult?].self
        ) { group in
            for index in 0..<16 {
                group.addTask {
                    try? await service.search(query: "project-\(index)", seedPaths: [])
                }
            }
            var values: [MobileTaskDirectorySearchResult?] = []
            for await value in group {
                values.append(value)
            }
            return values
        }

        #expect(results.count == 16)
        #expect(results.allSatisfy { $0?.directories.count == 1 })
    }

    @Test func mergesLiveWalkMatchesAndReportsWalkCompleteness() async throws {
        let service = MobileTaskDirectorySearchService(
            homeDirectory: URL(fileURLWithPath: "/Users/test", isDirectory: true),
            metadataSearchOperation: { _, _, _ in
                MobileTaskDirectoryMetadataQueryRunner.Snapshot(
                    paths: [],
                    gatheringComplete: true,
                    totalMatchCount: 0,
                    truncated: false
                )
            },
            directoryExists: { _ in true },
            filesystemWalkOperation: { _, roots in
                #expect(roots.first == "/Users/test")
                return MobileTaskDirectoryFilesystemWalker.Outcome(
                    matches: ["/Users/test/Dev/Manaflow/hmuxterm-hq"],
                    visitedDirectoryCount: 42,
                    complete: true
                )
            }
        )

        let result = try await service.search(query: "hmux", seedPaths: [])

        #expect(result.directories == ["/Users/test/Dev/Manaflow/hmuxterm-hq"])
        #expect(result.scope == .allIndexedVolumes)
        #expect(result.filesystemComplete)
        #expect(result.indexedMatchCount == 0)
    }

    @Test func metadataFailureStillReturnsLiveWalkMatches() async throws {
        let service = MobileTaskDirectorySearchService(
            homeDirectory: URL(fileURLWithPath: "/Users/test", isDirectory: true),
            metadataSearchOperation: { _, _, _ in
                throw MobileTaskDirectoryMetadataQueryRunner.QueryError.unavailable
            },
            directoryExists: { _ in true },
            filesystemWalkOperation: { _, _ in
                MobileTaskDirectoryFilesystemWalker.Outcome(
                    matches: ["/Users/test/Dev/hmux-lite"],
                    visitedDirectoryCount: 7,
                    complete: true
                )
            }
        )

        let result = try await service.search(query: "hmux", seedPaths: [])

        #expect(result.directories == ["/Users/test/Dev/hmux-lite"])
        #expect(result.scope == .contextualCandidatesOnly)
        #expect(result.filesystemComplete)
    }

    @Test func walkRootsAreTheHomePlusExternalContextualParents() {
        func searchable(_ path: String) -> MobileTaskDirectorySearchService.SearchablePath {
            MobileTaskDirectorySearchService.SearchablePath(
                path: path,
                pathBytes: Array(path.utf8),
                foldedPath: path.lowercased(),
                components: path.split(separator: "/").map(String.init),
                basename: path.split(separator: "/").last.map(String.init) ?? path
            )
        }

        let roots = MobileTaskDirectorySearchService.walkRoots(
            homeDirectory: URL(fileURLWithPath: "/Users/test", isDirectory: true),
            contextual: [
                searchable("/Users/test/Dev/project"),
                searchable("/Volumes/Work/client-a"),
                searchable("/Volumes/Work/client-b"),
                searchable("/root-level"),
            ]
        )

        #expect(roots == ["/Users/test", "/Volumes/Work"])
    }
}

@Suite struct MobileTaskDirectoryFilesystemWalkerTests {
    private func makeFixtureTree() throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("walker-fixture-\(UUID().uuidString)", isDirectory: true)
        let directories = [
            "Dev/Manaflow/hmuxterm-hq",
            "Dev/hmux-lite",
            "Dev/unrelated",
            "Documents/notes",
            "node_modules/hmux-package",
            "Library/hmux-library",
            ".hidden-hmux/hmux-nested",
        ]
        for directory in directories {
            try FileManager.default.createDirectory(
                at: root.appendingPathComponent(directory, isDirectory: true),
                withIntermediateDirectories: true
            )
        }
        return root
    }

    @Test func findsNestedNameMatchesWithoutDescendingIntoPrunedOrHiddenTrees() throws {
        let root = try makeFixtureTree()
        defer { try? FileManager.default.removeItem(at: root) }

        let outcome = MobileTaskDirectoryFilesystemWalker()
            .search(query: "hmux", roots: [root.path])

        let matches = Set(outcome.matches)
        #expect(matches.contains(root.appendingPathComponent("Dev/Manaflow/hmuxterm-hq").path))
        #expect(matches.contains(root.appendingPathComponent("Dev/hmux-lite").path))
        // A pruned or hidden directory is reported when its own name matches,
        // but nothing inside it is reachable.
        #expect(matches.contains(root.appendingPathComponent(".hidden-hmux").path))
        #expect(!matches.contains(root.appendingPathComponent("node_modules/hmux-package").path))
        #expect(!matches.contains(root.appendingPathComponent("Library/hmux-library").path))
        #expect(!matches.contains(root.appendingPathComponent(".hidden-hmux/hmux-nested").path))
        #expect(outcome.complete)
        #expect(outcome.visitedDirectoryCount > 0)
    }

    @Test func visitBudgetStopsTheWalkAndReportsIncompleteness() throws {
        let root = try makeFixtureTree()
        defer { try? FileManager.default.removeItem(at: root) }

        var budget = MobileTaskDirectoryFilesystemWalker.Budget()
        budget.maximumVisitedDirectories = 1
        let outcome = MobileTaskDirectoryFilesystemWalker(budget: budget)
            .search(query: "hmux", roots: [root.path])

        #expect(outcome.visitedDirectoryCount == 1)
        #expect(!outcome.complete)
    }

    @Test func matchBudgetStopsTheWalkAndReportsIncompleteness() throws {
        let root = try makeFixtureTree()
        defer { try? FileManager.default.removeItem(at: root) }

        var budget = MobileTaskDirectoryFilesystemWalker.Budget()
        budget.maximumMatches = 1
        let outcome = MobileTaskDirectoryFilesystemWalker(budget: budget)
            .search(query: "hmux", roots: [root.path])

        #expect(outcome.matches.count == 1)
        #expect(!outcome.complete)
    }

    @Test func matchingIsCaseAndDiacriticInsensitiveOnTheFinalQueryComponent() throws {
        let root = try makeFixtureTree()
        defer { try? FileManager.default.removeItem(at: root) }

        let outcome = MobileTaskDirectoryFilesystemWalker()
            .search(query: "Manaflow CMÙX", roots: [root.path])

        #expect(outcome.matches.contains(root.appendingPathComponent("Dev/Manaflow/hmuxterm-hq").path))
    }
}
