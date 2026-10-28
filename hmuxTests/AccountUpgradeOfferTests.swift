import HMUXMobileCore
import HmuxCommandPalette
import Foundation
import Testing

#if canImport(hmux_DEV)
@testable import hmux_DEV
#elseif canImport(hmux)
@testable import hmux
#endif

/// Every upgrade entrypoint (account menu, sidebar help menu, Help menu,
/// command palette) offers the tier above the account's plan: Free and Go
/// see Pro, Pro sees Max, and Max sees nothing.
@MainActor
struct AccountUpgradeOfferTests {
    @Test func menuTitlesNameTheOfferedTier() {
        #expect(ProUpgradePresenter.upgradeMenuTitle(for: .pro) == String(
            localized: "menu.help.upgradeToPro", defaultValue: "Upgrade to hmux Pro…"
        ))
        #expect(ProUpgradePresenter.upgradeMenuTitle(for: .max) == String(
            localized: "menu.help.upgradeToMax", defaultValue: "Upgrade to hmux Max…"
        ))
    }

    @Test(arguments: [
        (HmuxPlanTier.free, Optional(HmuxPlanTier.pro)),
        (HmuxPlanTier.go, Optional(HmuxPlanTier.pro)),
        (HmuxPlanTier.pro, Optional(HmuxPlanTier.max)),
        (HmuxPlanTier.max, nil),
    ])
    func paletteCommandFollowsTheTier(tier: HmuxPlanTier, expected: HmuxPlanTier?) throws {
        let command = try #require(ContentView.commandPaletteProCommandContributions().first {
            $0.commandId == ContentView.commandPaletteProUpgradeCommandId
        })
        var context = CommandPaletteContextSnapshot()
        let offer = HmuxPlanTier.upgradeOffer(isSignedIn: true, knownTier: tier)
        context.setString(
            CommandPaletteContextKeys.accountUpgradeOffer,
            ContentView.commandPaletteUpgradeOfferValue(offer)
        )
        #expect(command.when(context) == (expected != nil))
        if let expected {
            #expect(command.title(context) == ProUpgradePresenter.upgradeCommandTitle(for: expected))
        }
    }

    @Test func paletteHidesTheUpgradeWhileThePlanIsUnknown() throws {
        let command = try #require(ContentView.commandPaletteProCommandContributions().first {
            $0.commandId == ContentView.commandPaletteProUpgradeCommandId
        })
        var context = CommandPaletteContextSnapshot()
        context.setString(
            CommandPaletteContextKeys.accountUpgradeOffer,
            ContentView.commandPaletteUpgradeOfferValue(HmuxPlanTier.upgradeOffer(isSignedIn: true, knownTier: nil))
        )
        #expect(!command.when(context))
    }

    @Test func footerBadgeIsHiddenForProAndMax() {
        for tier in HmuxPlanTier.allCases {
            #expect(
                SidebarFooterPresentationPolicy.isUpgradeVisible(isProActive: tier.includesPro) == !tier.includesPro,
                "\(tier)"
            )
        }
    }
}
