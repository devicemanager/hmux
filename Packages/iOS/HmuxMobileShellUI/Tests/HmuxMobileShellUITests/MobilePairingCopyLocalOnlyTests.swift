#if os(iOS)
import Testing
@testable import HmuxMobileShellUI

/// A local-only app has no account, team or Cloud, so its empty Computers
/// and workspace screens must explain only the local pairing code.
@Suite struct MobilePairingCopyLocalOnlyTests {
    private let macPairing = "Select the same team on both devices."
    private let cloudHint = "No Mac? Create a Cloud machine in the Cloud tab."

    @Test func localOnlyEmptyWorkspaceMessageNamesOnlyTheLocalPairingCode() {
        let message = MobilePairingCopy(isLocalOnly: true).emptyWorkspaceMessage
        #expect(message.contains("Show Pairing Code"))
        #expect(message.contains("Tailscale"))
        #expect(!message.localizedCaseInsensitiveContains("account"))
        #expect(!message.localizedCaseInsensitiveContains("team"))
        #expect(!message.localizedCaseInsensitiveContains("Cloud"))
    }

    @Test func localOnlyComputersEmptyDescriptionDropsAccountAndCloudGuidance() {
        let copy = MobilePairingCopy(isLocalOnly: true)
        #expect(
            copy.computersEmptyDescription(macPairing: macPairing, cloudHint: cloudHint)
                == copy.emptyWorkspaceMessage
        )
    }

    @Test func accountBuildsKeepTheirGuidance() {
        let copy = MobilePairingCopy(isLocalOnly: false)
        #expect(copy.emptyWorkspaceMessage.contains("account"))
        #expect(
            copy.computersEmptyDescription(macPairing: macPairing, cloudHint: cloudHint)
                == "\(macPairing) \(copy.emptyWorkspaceMessage)\n\n\(cloudHint)"
        )
        #expect(
            copy.computersEmptyDescription(macPairing: macPairing, cloudHint: nil)
                == "\(macPairing) \(copy.emptyWorkspaceMessage)"
        )
    }
}
#endif
