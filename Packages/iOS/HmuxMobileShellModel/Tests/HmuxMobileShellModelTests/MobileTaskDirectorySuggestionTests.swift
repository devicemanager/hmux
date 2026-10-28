import Foundation
import Testing
@testable import HmuxMobileShellModel

@Suite struct MobileTaskDirectorySuggestionTests {
    @Test func strictMatchesOutrankHigherContextLenientMatches() {
        let index = MobileTaskDirectorySuggestionIndex(candidates: [
            candidate("/Users/me/alpha-hmux", source: .activeTerminal),
            candidate("/Users/me/hmux", source: .openWorkspace),
        ])

        #expect(index.suggestions(matching: "/Users/me/hmux").map(\.path) == [
            "/Users/me/hmux",
            "/Users/me/alpha-hmux",
        ])
    }

    @Test func exactBasenameOutranksHigherContextDescendantMatch() {
        let project = "/Users/me/Dev/Manaflow/hmuxterm-hq/worktrees/feat-ios-task-composer"
        let index = MobileTaskDirectorySuggestionIndex(candidates: [
            candidate("\(project)/web", source: .activeTerminal),
            candidate(project, source: .filesystemSearch),
        ])

        #expect(index.suggestions(matching: "feat-ios-task-composer").map(\.path) == [
            project,
            "\(project)/web",
        ])
    }

    @Test func activeAndRecentContextOrdersEqualMatches() {
        let now = Date(timeIntervalSince1970: 10_000)
        let index = MobileTaskDirectorySuggestionIndex(candidates: [
            candidate("/Users/me/hmux-old", source: .openWorkspace, date: now.addingTimeInterval(-8 * 86_400)),
            candidate("/Users/me/hmux-active", source: .activeWorkspace, date: now.addingTimeInterval(-30)),
            candidate("/Users/me/hmux-recent", source: .recentSuccessful, date: now.addingTimeInterval(-60), useCount: 8),
        ], now: now)

        #expect(index.suggestions(matching: "hmux").map(\.path) == [
            "/Users/me/hmux-active",
            "/Users/me/hmux-old",
            "/Users/me/hmux-recent",
        ])
    }

    @Test func componentPrefixesProvideLenientMatching() {
        let index = MobileTaskDirectorySuggestionIndex(candidates: [
            candidate("/Users/me/Dev/Manaflow/hmuxterm-hq", source: .openWorkspace),
            candidate("/Users/me/Dev/another-project", source: .activeWorkspace),
        ])

        #expect(index.suggestions(matching: "mana hmux").map(\.path) == [
            "/Users/me/Dev/Manaflow/hmuxterm-hq",
        ])
    }

    @Test func exactUTF8IdentityMergesSourcesWithoutMergingCanonicalUnicode() throws {
        let composed = "/Users/me/caf\u{00E9}"
        let decomposed = "/Users/me/cafe\u{301}"
        let index = MobileTaskDirectorySuggestionIndex(candidates: [
            candidate(composed, source: .templateDefault),
            candidate(composed, source: .activeWorkspace),
            candidate(decomposed, source: .recentSuccessful),
        ])

        let suggestions = index.suggestions(matching: "caf")
        #expect(suggestions.count == 2)
        #expect(suggestions[0].path == composed)
        #expect(suggestions[0].sources == [.templateDefault, .activeWorkspace])
        #expect(Array(suggestions[0].path.utf8) != Array(suggestions[1].path.utf8))
    }

    @Test func resultCountIsBoundedForLargeCandidateSets() {
        let candidates = (0..<10_000).map {
            candidate("/Users/me/project-\($0)", source: .openWorkspace)
        }
        let index = MobileTaskDirectorySuggestionIndex(candidates: candidates)

        let suggestions = index.suggestions(matching: "project", limit: 8)

        #expect(suggestions.count == 8)
        #expect(Set(suggestions.map(\.path)).count == 8)
    }

    private func candidate(
        _ path: String,
        source: MobileTaskDirectorySource,
        date: Date? = nil,
        useCount: Int = 0
    ) -> MobileTaskDirectoryCandidate {
        MobileTaskDirectoryCandidate(
            path: path,
            source: source,
            context: nil,
            lastUsedAt: date,
            useCount: useCount
        )
    }
}
