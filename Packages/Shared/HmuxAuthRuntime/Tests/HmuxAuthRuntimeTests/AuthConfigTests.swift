import HMUXAuthCore
import Testing
@testable import HmuxAuthRuntime

@Suite struct AuthConfigTests {
    @Test func productionUsesStackWhitelistedHmuxDomain() {
        let config = AuthConfig(environment: .production)

        #expect(config.magicLinkCallbackURL == "https://cmux.com/auth/callback")
        #expect(config.apiBaseURL == "https://cmux.com")
    }
}
