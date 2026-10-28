@testable import HmuxControlSocket
import HmuxSettings
import Foundation
import Testing

@Suite("Socket client authorization")
struct SocketClientAuthorizationTests {
    private let authorization = SocketClientAuthorization()

    @Test func hmuxOnlyFailsClosedWhenPeerPidIsUnavailable() {
        #expect(!authorization.isHmuxOnlyClientAllowed(
            peerProcessID: nil,
            peerHasSameUID: true,
            isDescendant: { _ in true }
        ))
    }

    @Test func hmuxOnlyAllowsDescendantPeerPid() {
        #expect(authorization.isHmuxOnlyClientAllowed(
            peerProcessID: 123,
            peerHasSameUID: false,
            isDescendant: { $0 == 123 }
        ))
    }

    @Test func hmuxOnlyRejectsNonDescendantPeerPid() {
        #expect(!authorization.isHmuxOnlyClientAllowed(
            peerProcessID: 123,
            peerHasSameUID: true,
            isDescendant: { _ in false }
        ))
    }

    @Test func hmuxOnlyAllowsReparentedClientWithInheritedCapability() throws {
        let authority = SocketClientCapabilityAuthority(
            secret: Data(repeating: 0xA5, count: SocketClientCapabilityAuthority.secureByteCount),
            audience: "com.hmuxterm.test"
        )
        let capability = authority.issueCapability(
            nonce: Data(repeating: 0x5A, count: SocketClientCapabilityAuthority.secureByteCount)
        )
        let envelope = try #require(SocketClientCapabilityEnvelope(capability: capability))
        let command = "hooks claude prompt-submit"

        #expect(authorization.authorizedCommand(
            envelope.wrap(command),
            peerProcessID: 123,
            peerHasSameUID: true,
            capabilityAuthority: authority,
            isDescendant: { _ in false }
        ) == command)
    }

    @Test func hmuxOnlyRejectsReparentedClientWithoutCapability() {
        let authority = SocketClientCapabilityAuthority(
            secret: Data(repeating: 0xA5, count: SocketClientCapabilityAuthority.secureByteCount),
            audience: "com.hmuxterm.test"
        )
        #expect(authorization.authorizedCommand(
            "hooks claude prompt-submit",
            peerProcessID: 123,
            peerHasSameUID: true,
            capabilityAuthority: authority,
            isDescendant: { _ in false }
        ) == nil)
    }

    @Test func hmuxOnlyRejectsCapabilityFromDifferentUser() throws {
        let authority = SocketClientCapabilityAuthority(
            secret: Data(repeating: 0xA5, count: SocketClientCapabilityAuthority.secureByteCount),
            audience: "com.hmuxterm.test"
        )
        let capability = authority.issueCapability(
            nonce: Data(repeating: 0x5A, count: SocketClientCapabilityAuthority.secureByteCount)
        )
        let envelope = try #require(SocketClientCapabilityEnvelope(capability: capability))
        #expect(authorization.authorizedCommand(
            envelope.wrap("hooks claude prompt-submit"),
            peerProcessID: 123,
            peerHasSameUID: false,
            capabilityAuthority: authority,
            isDescendant: { _ in false }
        ) == nil)
    }

    @Test func ownerOnlyAutomationModesRejectDifferentUser() {
        let authority = SocketClientCapabilityAuthority(
            secret: Data(repeating: 0xA5, count: SocketClientCapabilityAuthority.secureByteCount),
            audience: "com.hmuxterm.test"
        )

        for mode in [SocketControlMode.automation, .password] {
            #expect(authorization.authorizedCommand(
                "ping",
                accessMode: mode,
                peerProcessID: nil,
                peerHasSameUID: false,
                capabilityAuthority: authority,
                isDescendant: { _ in false }
            ) == nil)
        }
    }

    @Test func ownerOnlyAutomationModesAllowSameUser() {
        let authority = SocketClientCapabilityAuthority(
            secret: Data(repeating: 0xA5, count: SocketClientCapabilityAuthority.secureByteCount),
            audience: "com.hmuxterm.test"
        )

        for mode in [SocketControlMode.automation, .password] {
            #expect(authorization.authorizedCommand(
                "ping",
                accessMode: mode,
                peerProcessID: nil,
                peerHasSameUID: true,
                capabilityAuthority: authority,
                isDescendant: { _ in false }
            ) == "ping")
        }
    }

    @Test func allowAllDoesNotRequireSameUser() {
        let authority = SocketClientCapabilityAuthority(
            secret: Data(repeating: 0xA5, count: SocketClientCapabilityAuthority.secureByteCount),
            audience: "com.hmuxterm.test"
        )

        #expect(authorization.authorizedCommand(
            "ping",
            accessMode: .allowAll,
            peerProcessID: nil,
            peerHasSameUID: false,
            capabilityAuthority: authority,
            isDescendant: { _ in false }
        ) == "ping")
    }
}
