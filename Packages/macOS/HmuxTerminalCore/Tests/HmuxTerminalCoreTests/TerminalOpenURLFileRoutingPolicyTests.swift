import Foundation
import Testing
import HmuxTerminalCore

@Suite struct TerminalOpenURLFileRoutingPolicyTests {
    private let policy = TerminalOpenURLFileRoutingPolicy()

    @Test func explicitFileSchemeBypassesHmuxFileRouting() throws {
        let url = try #require(URL(string: "file:///Users/dev/out/ab_cosyvoice_emo.wav"))
        #expect(
            policy.shouldAttemptHmuxFileRouting(
                rawOpenURLValue: url.absoluteString,
                target: .external(url)
            ) == false
        )
    }

    @Test func localhostFileSchemeBypassesHmuxFileRouting() throws {
        let url = try #require(URL(string: "file://localhost/Users/dev/out/ab_cosyvoice_emo.wav"))
        #expect(
            policy.shouldAttemptHmuxFileRouting(
                rawOpenURLValue: url.absoluteString,
                target: .external(url)
            ) == false
        )
    }

    @Test func hostedFileTargetBypassesHmuxFileRoutingEvenWithoutRawScheme() throws {
        let url = try #require(URL(string: "file://remote-host/Users/dev/out/ab_cosyvoice_emo.wav"))
        #expect(
            policy.shouldAttemptHmuxFileRouting(
                rawOpenURLValue: "/Users/dev/out/ab_cosyvoice_emo.wav",
                target: .external(url)
            ) == false
        )
    }

    @Test func absolutePathCanStillUseHmuxFileRouting() {
        let url = URL(fileURLWithPath: "/Users/dev/project/README.md")
        #expect(
            policy.shouldAttemptHmuxFileRouting(
                rawOpenURLValue: "/Users/dev/project/README.md",
                target: .external(url)
            )
        )
    }

    @Test func nonFileTargetsBypassHmuxFileRouting() throws {
        let url = try #require(URL(string: "https://example.com/audio.wav"))
        #expect(
            policy.shouldAttemptHmuxFileRouting(
                rawOpenURLValue: url.absoluteString,
                target: .embeddedBrowser(url)
            ) == false
        )
    }
}
