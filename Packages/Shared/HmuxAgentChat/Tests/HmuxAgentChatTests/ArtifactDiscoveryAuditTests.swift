import Foundation
import Testing
@testable import HmuxAgentChat

@Suite("Artifact discovery audit", .serialized)
struct ArtifactDiscoveryAuditTests {
    @Test("audits real historical transcripts when explicitly enabled")
    func artifactDiscoveryAudit() {
        guard ProcessInfo.processInfo.environment["HMUX_ARTIFACT_AUDIT"] == "1" else {
            return
        }
        ArtifactDiscoveryAudit().run()
    }
}
