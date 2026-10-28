#if os(iOS)
import HmuxMobileSupport

struct MobilePairingCopy {
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
        L10n.string(
            "mobile.workspaces.empty.message",
            defaultValue: "Enable iOS pairing in hmux Settings > Mobile on your Mac, sign in to the same hmux account on both devices, and keep hmux running. Your Mac and its workspaces will appear here after pairing is enabled."
        )
    }
}
#endif
