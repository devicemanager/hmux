import Testing
import HmuxCore

@Suite("Workspace group identity resolution")
struct WorkspaceGroupIdentityResolutionTests {
    @Test("normalizes either accepted alias")
    func normalizesAliases() throws {
        let external = try WorkspaceGroupIdentityResolution(
            externalID: .string("  repo:hmux  ")
        )
        #expect(external.value == "repo:hmux")

        let retry = try WorkspaceGroupIdentityResolution(
            idempotencyKey: .string(" repo:hmux ")
        )
        #expect(retry.value == "repo:hmux")
    }

    @Test("accepts matching aliases after normalization")
    func matchingAliases() throws {
        let resolution = try WorkspaceGroupIdentityResolution(
            externalID: .string("repo:hmux"),
            idempotencyKey: .string(" repo:hmux ")
        )
        #expect(resolution.value == "repo:hmux")
    }

    @Test("omitted and null-equivalent inputs produce no identity")
    func absentInputs() throws {
        let resolution = try WorkspaceGroupIdentityResolution()
        #expect(resolution.value == nil)
    }

    @Test("rejects malformed, blank, and mismatched inputs")
    func validationErrors() {
        #expect(throws: WorkspaceGroupIdentityResolution.ValidationError.nonString(field: .externalID)) {
            try WorkspaceGroupIdentityResolution(externalID: .invalid)
        }
        #expect(throws: WorkspaceGroupIdentityResolution.ValidationError.empty(field: .idempotencyKey)) {
            try WorkspaceGroupIdentityResolution(idempotencyKey: .string(" \n "))
        }
        #expect(throws: WorkspaceGroupIdentityResolution.ValidationError.mismatchedAliases) {
            try WorkspaceGroupIdentityResolution(
                externalID: .string("repo:a"),
                idempotencyKey: .string("repo:b")
            )
        }
    }
}
