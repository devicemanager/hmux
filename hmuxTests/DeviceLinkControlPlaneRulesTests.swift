import HMUXMobileCore
import HmuxIrxTransport
import HmuxSurfaceCatalogModel
import Foundation
import Testing

#if canImport(hmux_DEV)
@testable import hmux_DEV
#elseif canImport(hmux)
@testable import hmux
#endif

/// The issuing Worker must explicitly advertise the Mac admission rule.
@Suite("Devices: control-plane rules")
struct DeviceLinkControlPlaneRulesTests {
    private let selfID = "11111111-1111-1111-1111-111111111111"
    private let studioID = "22222222-2222-2222-2222-222222222222"

    @Test("The required rule set is the Mac-to-Mac inbound rule")
    func requiredRules() {
        #expect(DeviceLinkControlPlaneRules.current.required == [DeviceLinkControlPlaneRules.macPeerInbound])
        let bare = V2Directory(devices: [], issuedAt: 1, permissionExpiresAt: 2, relayURLs: [], revision: 1, teamID: "team")
        #expect(!DeviceLinkControlPlaneRules.current.isSatisfied(by: bare))
        let legacy = V2Directory(devices: [], inboundPeers: [], issuedAt: 1, permissionExpiresAt: 2,
            relayURLs: [], revision: 1, teamID: "team")
        #expect(!DeviceLinkControlPlaneRules.current.isSatisfied(by: legacy))
        let named = V2Directory(devices: [], issuedAt: 1, permissionExpiresAt: 2, relayURLs: [], revision: 1,
            rules: ["hmux.mac-peer-inbound.v1", "hmux.future.v9"], teamID: "team")
        #expect(DeviceLinkControlPlaneRules.current.isSatisfied(by: named))
    }

    @Test("Only a named admission rule enables Mac links", arguments: [true, false])
    func controlPlaneRules(advertised: Bool) throws {
        func record(deviceID: String, endpoint: String) -> V2DeviceRecord {
            let identity = V2Identity(appNamespace: "com.hmuxterm.app.nightly", buildTag: "nightly",
                deviceID: deviceID, environment: "production", projectID: "project",
                teamID: "work-team", userID: "my-account")
            let metadata = V2DeviceMetadata(appVersion: "0.64.25-nightly.1", capabilities: ["irx-v2", "hmux.mac-devices.v1", "hmux.mac-host.v1"],
                displayName: "Studio", pairingEnabled: true, platform: .mac, relayURLs: [])
            return V2DeviceRecord(descriptor: V2DeviceDescriptor(endpointID: endpoint, identity: identity,
                identityGeneration: 0, metadata: metadata), deviceRecordID: deviceID, revision: 1, revoked: false)
        }
        let own = record(deviceID: selfID, endpoint: String(repeating: "cd", count: 32))
        var cache = V2CachedState(identity: own.descriptor.identity)
        cache.device = own
        cache.directory = V2Directory(devices: [record(deviceID: studioID, endpoint: String(repeating: "ab", count: 32))],
            inboundPeers: [],
            issuedAt: 1000, permissionExpiresAt: 1060, relayURLs: [], revision: 1,
            rules: advertised ? [DeviceLinkControlPlaneRules.macPeerInbound] : nil, teamID: "work-team")
        let macs = DeviceIrxClient.displayBindings(cache: cache, now: Date(timeIntervalSince1970: 1001))
        #expect(macs.map(\.controlPlaneSupportsMacPeers) == [advertised])
        let records = DeviceDirectoryMerge.merge(.init(
            authenticatedMacs: macs, ownersKnown: true, selfInstance: SurfaceDeviceInstanceID(deviceID: selfID, tag: "nightly"),
            currentUserID: "my-account", resolvedTeamID: "work-team"
        ))
        let row = try #require(records.first)
        #expect(row.isDialable, "the Mac stays listed and dialable; the link decides what to say")
        #expect(row.controlPlaneSupport == (advertised ? .supported : .outdated))
        let retained = DeviceDirectoryMerge.merge(.init(
            previous: records, selfInstance: SurfaceDeviceInstanceID(deviceID: selfID, tag: "nightly"),
            currentUserID: "my-account", resolvedTeamID: "work-team"
        ))
        #expect(retained.first?.controlPlaneSupport == row.controlPlaneSupport, "a directory outage keeps the last verdict")
    }
}
