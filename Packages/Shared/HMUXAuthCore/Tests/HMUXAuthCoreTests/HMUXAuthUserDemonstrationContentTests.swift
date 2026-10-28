import HMUXAuthCore
import Foundation
import Testing

/// The demonstration-content activation gate: a server-written boolean on the
/// Stack account's `clientReadOnlyMetadata`, mirrored onto `HMUXAuthUser`.
/// Only an explicit JSON `true` activates it, unknown/legacy payloads fail
/// closed, and persisted identity cards from older builds decode as
/// not-flagged.
@Suite("HMUXAuthUser demonstration content")
struct HMUXAuthUserDemonstrationContentTests {
    @Test("Metadata resolves only an explicit boolean true")
    func metadataResolvesOnlyExplicitBooleanTrue() {
        func resolve(_ metadata: [String: Any]?) -> Bool {
            HMUXAuthUser.demonstrationContentEnabled(
                fromClientReadOnlyMetadata: metadata
            )
        }

        #expect(resolve(["hmuxReviewDemoContent": true]))
        #expect(!resolve(["hmuxReviewDemoContent": false]))
        #expect(!resolve(nil))
        #expect(!resolve([:]))
        #expect(!resolve(["hmuxPlan": "pro"]))
        // Fail closed on every non-boolean shape a bad write could produce.
        #expect(!resolve(["hmuxReviewDemoContent": "true"]))
        #expect(!resolve(["hmuxReviewDemoContent": 1]))
        #expect(!resolve(["hmuxReviewDemoContent": 2.5]))
        #expect(!resolve(["hmuxReviewDemoContent": ["enabled": true]]))
        #expect(!resolve(["hmuxReviewDemoContent": NSNull()]))
    }

    @Test("Metadata parsed from real JSON activates the flag")
    func metadataParsedFromJSONActivates() throws {
        let payload = #"{"hmuxReviewDemoContent": true, "hmuxPlan": "pro"}"#
        let metadata = try JSONSerialization.jsonObject(
            with: Data(payload.utf8)
        ) as? [String: Any]
        #expect(HMUXAuthUser.demonstrationContentEnabled(
            fromClientReadOnlyMetadata: metadata
        ))

        let numericPayload = #"{"hmuxReviewDemoContent": 1}"#
        let numericMetadata = try JSONSerialization.jsonObject(
            with: Data(numericPayload.utf8)
        ) as? [String: Any]
        #expect(!HMUXAuthUser.demonstrationContentEnabled(
            fromClientReadOnlyMetadata: numericMetadata
        ))
    }

    @Test("Identity cards persisted before the flag decode as not flagged")
    func legacyIdentityCardsDecodeAsNotFlagged() throws {
        let legacy = #"{"id": "user-1", "primaryEmail": "user@example.com"}"#
        let user = try JSONDecoder().decode(HMUXAuthUser.self, from: Data(legacy.utf8))
        #expect(!user.demonstrationContentEnabled)
        #expect(user.id == "user-1")
    }

    @Test("The flag round-trips through the persisted identity card")
    func flagRoundTripsThroughCodable() throws {
        let flagged = HMUXAuthUser(
            id: "user-2",
            primaryEmail: "review@example.com",
            displayName: "Review",
            demonstrationContentEnabled: true
        )
        let decoded = try JSONDecoder().decode(
            HMUXAuthUser.self,
            from: JSONEncoder().encode(flagged)
        )
        #expect(decoded == flagged)
        #expect(decoded.demonstrationContentEnabled)
    }

    @Test("Default construction is not flagged")
    func defaultConstructionIsNotFlagged() {
        let user = HMUXAuthUser(id: "user-3", primaryEmail: nil, displayName: nil)
        #expect(!user.demonstrationContentEnabled)
    }
}
