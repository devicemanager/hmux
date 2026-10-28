import Testing
@testable import hmuxFeature

@Suite
struct MobileKeychainAccessGroupPolicyTests {
    @Test
    func acceptsDevTagAndProductionGroups() {
        #expect(String.hmuxKeychainAccessGroup(from:
            "7WLXT3NR37.dev.hmux.ios.tflex"
        ) == "7WLXT3NR37.dev.hmux.ios.tflex")
        #expect(String.hmuxKeychainAccessGroup(from:
            "7WLXT3NR37.com.hmux.app"
        ) == "7WLXT3NR37.com.hmux.app")
    }

    @Test
    func trimsWhitespaceAroundAValidGroup() {
        #expect(String.hmuxKeychainAccessGroup(from:
            " 7WLXT3NR37.dev.hmux.app.beta\n"
        ) == "7WLXT3NR37.dev.hmux.app.beta")
    }

    @Test
    func rejectsPrefixLessNilAndMalformedValues() {
        #expect(String.hmuxKeychainAccessGroup(from: "dev.hmux.app.beta") == nil)
        #expect(String.hmuxKeychainAccessGroup(from: nil) == nil)
        #expect(String.hmuxKeychainAccessGroup(from: "") == nil)
        #expect(String.hmuxKeychainAccessGroup(from: ".dev.hmux.app.beta") == nil)
        #expect(String.hmuxKeychainAccessGroup(from:
            "$(AppIdentifierPrefix)dev.hmux.app.beta"
        ) == nil)
    }

    @Test
    func rejectsEmptyBundleComponentsAfterTheTeamIdentifier() {
        // An empty interior or trailing component is a bake gone wrong, not a
        // grantable group; it must fall back rather than resolve.
        #expect(String.hmuxKeychainAccessGroup(from: "7WLXT3NR37..dev") == nil)
        #expect(String.hmuxKeychainAccessGroup(from: "7WLXT3NR37.dev.") == nil)
        #expect(String.hmuxKeychainAccessGroup(from:
            "7WLXT3NR37.dev..hmux.app.beta"
        ) == nil)
    }
}
