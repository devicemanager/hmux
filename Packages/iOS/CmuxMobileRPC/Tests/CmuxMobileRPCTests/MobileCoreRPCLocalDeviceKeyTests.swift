import CMUXMobileCore
import Foundation
import Testing
@testable import CmuxMobileRPC

/// A locally paired Mac authorizes with the device key it issued, so the
/// phone must send that key, and only to the exact endpoint it belongs to,
/// without ever minting an account token.
@Suite struct MobileCoreRPCLocalDeviceKeyTests {
    private func client(
        host: String,
        keyHost: String,
        transport: QueuedCancellationProbeTransport,
        stackTokenRequested: AsyncFlag
    ) throws -> MobileCoreRPCClient {
        let route = try hostPortRoute(kind: .tailscale, host: host, port: 4399)
        let runtime = TestMobileSyncRuntime(
            transportFactory: IntentRecordingTransportFactory(
                transport: transport,
                capture: TransportRequestCapture()
            ),
            stackAccessTokenProvider: {
                await stackTokenRequested.set()
                return "account-token"
            },
            localDeviceKeys: InMemoryLocalDeviceKeys(host: keyHost, port: 4399, key: "phone-key")
        )
        let ticket = try CmxAttachTicket(
            workspaceID: "",
            terminalID: nil,
            macDeviceID: "manual-\(host):4399",
            macDisplayName: "Local Mac",
            routes: [route],
            expiresAt: nil,
            authToken: nil
        )
        return MobileCoreRPCClient(
            runtime: runtime,
            route: route,
            ticket: ticket,
            userTailscalePairingAuthorization: try CmxUserTailscalePairingAuthorization(host: host, port: 4399)
        )
    }

    @Test func keyedEndpointSendsDeviceKeyInsteadOfAccountToken() async throws {
        let transport = QueuedCancellationProbeTransport()
        let stackTokenRequested = AsyncFlag()
        let client = try client(
            host: "100.64.0.5",
            keyHost: "100.64.0.5",
            transport: transport,
            stackTokenRequested: stackTokenRequested
        )
        let task = Task { try await client.sendRequest(try MobileCoreRPCClient.requestData(method: "workspace.list")) }
        let frame = try #require(try await transport.waitForSentRequestCount(1).first)

        #expect(frame.deviceKey == "phone-key")
        #expect(frame.stackAccessToken == nil)
        #expect(await stackTokenRequested.isSet() == false)
        task.cancel()
        await transport.releaseFirstSend()
        _ = try? await task.value
    }

    @Test func keyIsNotSentToAnotherEndpoint() async throws {
        let transport = QueuedCancellationProbeTransport()
        let stackTokenRequested = AsyncFlag()
        let client = try client(
            host: "100.64.0.6",
            keyHost: "100.64.0.5",
            transport: transport,
            stackTokenRequested: stackTokenRequested
        )
        let task = Task { try await client.sendRequest(try MobileCoreRPCClient.requestData(method: "workspace.list")) }
        let frame = try #require(try await transport.waitForSentRequestCount(1).first)

        #expect(frame.deviceKey == nil)
        task.cancel()
        await transport.releaseFirstSend()
        _ = try? await task.value
    }

    @Test func pairingRedemptionCarriesNoCredential() async throws {
        let transport = QueuedCancellationProbeTransport()
        let stackTokenRequested = AsyncFlag()
        let client = try client(
            host: "100.64.0.6",
            keyHost: "100.64.0.5",
            transport: transport,
            stackTokenRequested: stackTokenRequested
        )
        let request = try MobileCoreRPCClient.requestData(
            method: CmxLocalPairing.pairMethod,
            params: ["pairing_code": "code"]
        )
        let task = Task { try await client.sendRequest(request) }
        let frame = try #require(try await transport.waitForSentRequestCount(1).first)

        #expect(frame.method == CmxLocalPairing.pairMethod)
        #expect(!frame.hasAuth)
        #expect(await stackTokenRequested.isSet() == false)
        task.cancel()
        await transport.releaseFirstSend()
        _ = try? await task.value
    }
}

/// Holds one endpoint key, standing in for the Keychain store.
final class InMemoryLocalDeviceKeys: CmxLocalDeviceKeyStoring, @unchecked Sendable {
    private let host: String
    private let port: Int
    private let key: String

    init(host: String, port: Int, key: String) {
        self.host = host
        self.port = port
        self.key = key
    }

    func save(_ credential: CmxLocalDeviceCredential, hosts: [String], port: Int) throws {}

    func credential(host: String, port: Int) -> CmxLocalDeviceCredential? {
        guard host == self.host, port == self.port else { return nil }
        return CmxLocalDeviceCredential(deviceKey: key, deviceID: "phone", macDeviceID: "mac", macDisplayName: nil)
    }
}
