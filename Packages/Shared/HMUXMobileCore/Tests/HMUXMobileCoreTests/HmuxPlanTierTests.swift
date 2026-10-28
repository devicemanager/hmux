import Testing
@testable import HMUXMobileCore

@Suite struct HmuxPlanTierTests {
    @Test func everyHigherTierIncludesTheFeaturesBelowIt() {
        #expect(HmuxPlanTier.free.includesCloud == false)
        #expect(HmuxPlanTier.free.includesPro == false)
        #expect(HmuxPlanTier.free.includesMax == false)

        #expect(HmuxPlanTier.go.includesCloud)
        #expect(HmuxPlanTier.go.includesPro == false)
        #expect(HmuxPlanTier.go.includesMax == false)

        #expect(HmuxPlanTier.pro.includesCloud)
        #expect(HmuxPlanTier.pro.includesPro)
        #expect(HmuxPlanTier.pro.includesMax == false)

        #expect(HmuxPlanTier.max.includesCloud)
        #expect(HmuxPlanTier.max.includesPro)
        #expect(HmuxPlanTier.max.includesMax)
    }

    @Test func planIDsMapToTiers() {
        #expect(HmuxPlanTier(planID: "free") == .free)
        #expect(HmuxPlanTier(planID: "go") == .go)
        #expect(HmuxPlanTier(planID: "pro") == .pro)
        #expect(HmuxPlanTier(planID: " MAX ") == .max)
        // Team and Founder's Edition grant the Pro feature set.
        #expect(HmuxPlanTier(planID: "team") == .pro)
        #expect(HmuxPlanTier(planID: "founders") == .pro)
        #expect(HmuxPlanTier(planID: "enterprise") == nil)
        #expect(HmuxPlanTier(planID: "") == nil)
        #expect(HmuxPlanTier(planID: nil) == nil)
    }

    @Test func nextUpgradeOffersTheTierAbove() {
        #expect(HmuxPlanTier.free.nextUpgrade == .pro)
        #expect(HmuxPlanTier.go.nextUpgrade == .pro)
        #expect(HmuxPlanTier.pro.nextUpgrade == .max)
        #expect(HmuxPlanTier.max.nextUpgrade == nil)
    }

    @Test func maxSubscriberResolvesToMaxFromTheExactPlan() {
        // `/api/billing/plan` reports a Max subscriber as planId "pro" for
        // older clients and carries "max" in subscriptionPlanId.
        let tier = HmuxPlanTier.resolved(
            subscriptionPlanID: "max",
            planID: "pro",
            teamPlanID: "free",
            isPro: true
        )
        #expect(tier == .max)
        #expect(tier.nextUpgrade == nil)
    }

    @Test func goSubscriberIsNotPromotedToProByTheLegacyFlag() {
        // The service sets isPro for every paid personal plan, Go included.
        let tier = HmuxPlanTier.resolved(
            subscriptionPlanID: "go",
            planID: "pro",
            teamPlanID: "free",
            isPro: true
        )
        #expect(tier == .go)
        #expect(tier.nextUpgrade == .pro)
    }

    @Test func paidTeamRaisesAFreePersonalPlan() {
        let tier = HmuxPlanTier.resolved(
            subscriptionPlanID: "free",
            planID: "free",
            teamPlanID: "team",
            isPro: false
        )
        #expect(tier == .pro)
    }

    @Test func personalMaxIsKeptOnAFreeOrTeamWorkspace() {
        #expect(HmuxPlanTier.resolved(subscriptionPlanID: "max", planID: "pro", teamPlanID: "team", isPro: true) == .max)
    }

    @Test func olderServersFallBackToTheLegacyPlanFamily() {
        #expect(HmuxPlanTier.resolved(subscriptionPlanID: nil, planID: "pro", teamPlanID: nil, isPro: true) == .pro)
        #expect(HmuxPlanTier.resolved(subscriptionPlanID: nil, planID: nil, teamPlanID: nil, isPro: true) == .pro)
        #expect(HmuxPlanTier.resolved(subscriptionPlanID: nil, planID: nil, teamPlanID: nil, isPro: false) == .free)
    }

    @Test func upgradeOfferFollowsTheKnownTier() {
        // Signed out: the entry plan is the useful offer.
        #expect(HmuxPlanTier.upgradeOffer(isSignedIn: false, knownTier: nil) == .pro)
        // Signed in but the plan is still loading or its fetch failed: never
        // read that as Free, so offer nothing rather than the wrong plan.
        #expect(HmuxPlanTier.upgradeOffer(isSignedIn: true, knownTier: nil) == nil)
        #expect(HmuxPlanTier.upgradeOffer(isSignedIn: true, knownTier: .free) == .pro)
        #expect(HmuxPlanTier.upgradeOffer(isSignedIn: true, knownTier: .go) == .pro)
        #expect(HmuxPlanTier.upgradeOffer(isSignedIn: true, knownTier: .pro) == .max)
        #expect(HmuxPlanTier.upgradeOffer(isSignedIn: true, knownTier: .max) == nil)
    }
}
