#if os(iOS)
import HMUXMobileCore
import HmuxMobileSupport

struct MobilePairingCopy {
    /// Whether this is the account-free app that pairs only through the
    /// Mac's local pairing code.
    var isLocalOnly = CmxLocalOnlyMode.isEnabled()

    var enableOnMacShort: String {
        L10n.string(
            "mobile.pairing.enableOnMac.short",
            defaultValue: "Enable iOS pairing in hmux Settings > Mobile on your Mac."
        )
    }

    var enableOnMac: String {
        L10n.string(
            "mobile.pairing.enableOnMac",
            defaultValue: "Before pairing, open hmux Settings > Mobile on the Mac and turn on Enable iOS pairing. This Mac stays hidden from iOS while it is off."
        )
    }

    var emptyWorkspaceMessage: String {
        // No account, team or Cloud exists here: the Mac's local pairing
        // code is the only way to add it.
        if isLocalOnly {
            return L10n.string(
                "mobile.workspaces.empty.localOnly.message",
                defaultValue: "On your Mac, open Mobile Pairing, click Show Pairing Code, and scan it from Add Computer. Both devices must be on the same Tailscale network, and hmux must keep running on the Mac."
            )
        }
        return L10n.string(
            "mobile.workspaces.empty.message",
            defaultValue: "Enable iOS pairing in hmux Settings > Mobile on your Mac, sign in to the same hmux account on both devices, and keep hmux running. Your Mac and its workspaces will appear here after pairing is enabled."
        )
    }

    /// The empty Computers list text: how to pair a Mac, then the Cloud
    /// alternative when this build offers Cloud. A local-only build gives
    /// only its local pairing steps.
    func computersEmptyDescription(macPairing: String, cloudHint: String?) -> String {
        guard !isLocalOnly else { return emptyWorkspaceMessage }
        let pairing = "\(macPairing) \(emptyWorkspaceMessage)"
        guard let cloudHint else { return pairing }
        return "\(pairing)\n\n\(cloudHint)"
    }
}
#endif
