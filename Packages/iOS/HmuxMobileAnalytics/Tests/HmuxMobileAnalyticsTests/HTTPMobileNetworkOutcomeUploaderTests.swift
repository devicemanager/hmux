import Testing

@testable import HmuxMobileAnalytics

@Suite struct HTTPMobileNetworkOutcomeUploaderTests {
    @Test func statusPolicyRetriesMissingAuthAndTransientFailures() {
        #expect(HTTPMobileNetworkOutcomeUploader.result(forStatusCode: 204) == .accepted)
        #expect(HTTPMobileNetworkOutcomeUploader.result(forStatusCode: 401) == .retry)
        #expect(HTTPMobileNetworkOutcomeUploader.result(forStatusCode: 408) == .retry)
        #expect(HTTPMobileNetworkOutcomeUploader.result(forStatusCode: 429) == .retry)
        #expect(HTTPMobileNetworkOutcomeUploader.result(forStatusCode: 503) == .retry)
        #expect(HTTPMobileNetworkOutcomeUploader.result(forStatusCode: 422) == .drop)
    }
}
