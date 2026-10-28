import HmuxCloud
import HMUXMobileCore
import Foundation
import Testing

#if canImport(hmux_DEV)
@testable import hmux_DEV
#elseif canImport(hmux)
@testable import hmux
#endif

@Suite struct MacPairedMacBackupPublisherScopeTests {
    @Test func taggedPublisherTargetsTheMatchingIOSBackupScope() throws {
        let targetNamespace = try #require(MobileIOSAppNamespace(
            bundleIdentifier: "dev.hmux.ios.feature-a"
        ))
        let request = MacPairedMacBackupPublisher.makeRequest(
            url: try #require(URL(string: "https://presence.example/v1/sync/paired-macs")),
            accessToken: "token",
            teamID: "team-a",
            targetNamespace: targetNamespace,
            payload: Data("payload".utf8)
        )

        #expect(
            request.value(forHTTPHeaderField: "X-Hmux-Client-Scope")
                == "ios:v3:ZGV2LmNtdXguaW9zLmZlYXR1cmUtYQ"
        )
        #expect(request.value(forHTTPHeaderField: "X-Hmux-Team-Id") == "team-a")
    }

    @Test func releasePublishersTargetEachExactIOSBackupScope() throws {
        let bundleIdentifiers = [
            "com.hmux.app",
            "dev.hmux.app.beta",
            "dev.hmux.app.internal",
            "dev.hmux.app.demo",
        ]
        for bundleIdentifier in bundleIdentifiers {
            let targetNamespace = try #require(MobileIOSAppNamespace(
                bundleIdentifier: bundleIdentifier
            ))
            let request = MacPairedMacBackupPublisher.makeRequest(
                url: try #require(URL(
                    string: "https://presence.example/v1/sync/paired-macs"
                )),
                accessToken: "token",
                teamID: nil,
                targetNamespace: targetNamespace,
                payload: Data("payload".utf8)
            )

            #expect(
                request.value(forHTTPHeaderField: "X-Hmux-Client-Scope")
                    == targetNamespace.serverScope
            )
        }
    }

    @Test func publisherRecordCarriesCompareAndSetInstanceAuthority() throws {
        let record = MacPairedMacBackupRecordWire(
            macDeviceID: "mac-a",
            displayName: "Studio",
            routes: [],
            instanceTag: "feature-a",
            createdAt: 1,
            lastSeenAt: 2,
            isActive: true
        )
        let json = try #require(JSONSerialization.jsonObject(
            with: JSONEncoder().encode(record)
        ) as? [String: Any])

        #expect(json["instanceTag"] as? String == "feature-a")
        #expect(json["instanceTagWriteMode"] as? String == "compare_and_set")
    }
}
