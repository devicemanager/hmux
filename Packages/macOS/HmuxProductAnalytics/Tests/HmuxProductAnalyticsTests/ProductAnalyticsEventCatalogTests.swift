import HMUXMobileCore
import Testing

@testable import HmuxProductAnalytics

/// Pins every event name and property key. Renaming one breaks saved
/// insights; change this test, `docs/posthog/mac-product-analytics.md` and the insights
/// together.
@Suite("Product analytics event catalog")
struct ProductAnalyticsEventCatalogTests {
    static let catalog: [(ProductAnalyticsEvent, String, Set<String>)] = [
        (.upgradePromptShown(source: "mac_sidebar_badge", plan: "pro"), "hmux_upgrade_prompt_shown", ["source", "plan"]),
        (.upgradeEntrypointOpened(source: "mac_cloud_welcome", plan: "pro", destination: .pricingPage),
         "hmux_upgrade_entrypoint_opened", ["source", "client", "plan", "destination"]),
        (.upgradeBadgeDismissed(source: "mac_sidebar_badge"), "hmux_upgrade_badge_dismissed", ["source"]),
        (.planActivated(upgradeSource: "mac_sidebar_badge", sinceUpgradeClick: .from1to3m), "hmux_plan_activated",
         ["upgrade_source", "since_upgrade_click"]),
        (.planDeactivated, "hmux_plan_deactivated", []),
        (.cloudButtonShown, "hmux_cloud_button_shown", []),
        (.cloudButtonClicked(action: .introduceCloud), "hmux_cloud_button_clicked", ["action"]),
        (.cloudWelcomeShown(trigger: .launchAnnouncement, step: .upgrade), "hmux_cloud_welcome_shown", ["trigger", "next_step"]),
        (.cloudWelcomeButtonClicked(trigger: .newCloudMachine, step: .enable, button: .enable),
         "hmux_cloud_welcome_button_clicked", ["trigger", "next_step", "button"]),
        (.cloudWelcomeClosed(trigger: .newCloudWorkspace, step: .upgrade, outcome: .notNow, visibleFor: .from3to10s),
         "hmux_cloud_welcome_closed", ["trigger", "next_step", "outcome", "visible_for"]),
        (.signInStarted, "hmux_sign_in_started", []),
        (.signInSucceeded, "hmux_sign_in_succeeded", []),
        (.signInFailed(reason: .timedOut), "hmux_sign_in_failed", ["reason"]),
        (.signedOut, "hmux_signed_out", []),
        (.cloudEnableCompleted(result: .success), "hmux_cloud_enable_completed", ["result"]),
        (.cloudDisabled, "hmux_cloud_disabled", []),
        (.cloudMachineCreateStarted(memoryGB: 8), "hmux_cloud_machine_create_started", ["memory_gb"]),
        (.cloudMachineCreateStarted(memoryGB: nil), "hmux_cloud_machine_create_started", []),
        (.cloudMachineCreateSucceeded(duration: .from10to30s), "hmux_cloud_machine_create_succeeded", ["duration"]),
        (.cloudMachineCreateFailed(errorClass: .server, errorCode: "http_500", consecutiveFailures: 2),
         "hmux_cloud_machine_create_failed", ["error_class", "error_code", "consecutive_failures"]),
        (.cloudMachineDeleted, "hmux_cloud_machine_deleted", []),
        (.cloudMachineAttached(success: false, latency: .from1to3s, errorClass: .network),
         "hmux_cloud_machine_attached", ["success", "latency", "error_class"]),
        (.cloudWorkspaceCreated(machineChoice: .resolved, duration: .from3to10s), "hmux_cloud_workspace_created",
         ["machine_choice", "duration"]),
        (.cloudPlanLimitHit(limit: .activeMachines, operation: "create"), "hmux_cloud_plan_limit_hit", ["limit", "operation"]),
        (.activationMilestoneReached(milestone: .firstSplit, isNewInstall: true, daysSinceInstall: 0),
         "hmux_activation_milestone_reached", ["milestone", "is_new_install", "days_since_install"]),
        (.agentSessionStarted(agent: .codex), "hmux_agent_session_started", ["agent"]),
        (.agentSessionEnded(agent: .claudeCode), "hmux_agent_session_ended", ["agent"]),
        (.featureUsed(feature: .commandPalette), "hmux_feature_used", ["feature"]),
        (.appUpdated(direction: .upgrade, fromVersion: "0.65.1", toVersion: "0.65.2"), "hmux_app_updated",
         ["direction", "from_version", "to_version"]),
    ]

    @Test("every event has its pinned name and property keys")
    func pinnedNamesAndKeys() {
        for (event, name, keys) in Self.catalog {
            #expect(event.name == name)
            #expect(Set(event.properties.keys) == keys, "\(name)")
        }
    }

    @Test("names are unique, snake_case and hmux_ prefixed")
    func namingConvention() {
        let names = Set(Self.catalog.map(\.1))
        #expect(names.count == 28)
        for name in names {
            #expect(name.hasPrefix("hmux_"))
            #expect(name.allSatisfy { $0.isLowercase || $0 == "_" })
        }
    }

    @Test("the shared context keys are pinned and never collide with event keys")
    func contextKeys() {
        let context = ProductAnalyticsContext(appVersion: "0.65.2", appBuild: "1", channel: "nightly", osVersion: "15.5")
        #expect(Set(context.properties.keys) == [
            "app_version", "app_build", "channel", "os_version",
            "account_plan", "is_signed_in", "cloud_enabled", "workspaces_open",
        ])
        for (event, name, _) in Self.catalog {
            #expect(Set(event.properties.keys).isDisjoint(with: context.properties.keys), "\(name)")
        }
    }

    @Test("free text cannot reach a token property")
    func tokensRejectFreeText() {
        let event = ProductAnalyticsEvent.cloudMachineCreateFailed(
            errorClass: .client,
            errorCode: "Machine my-host.example.com failed: /Users/me",
            consecutiveFailures: 1
        )
        #expect(event.properties["error_code"] == .string("other"))
        let upgrade = ProductAnalyticsEvent.upgradePromptShown(source: "user@example.com", plan: "pro")
        #expect(upgrade.properties["source"] == .string("other"))
        let update = ProductAnalyticsEvent.appUpdated(direction: .upgrade, fromVersion: "/tmp/x", toVersion: "0.65.2")
        #expect(update.properties["from_version"] == .string("unknown"))
    }

    @Test("agent sources map to a closed set")
    func agentKinds() {
        #expect(AgentKind(hookSource: "claude") == .claudeCode)
        #expect(AgentKind(hookSource: "codex") == .codex)
        #expect(AgentKind(hookSource: "opencode") == .opencode)
        #expect(AgentKind(hookSource: "hmux-pi-extension") == .pi)
        #expect(AgentKind(hookSource: "my secret agent") == .other)
    }

    @Test("Cloud error codes classify without the raw message")
    func errorClasses() {
        #expect(CloudErrorClass(errorCode: "vm_active_limit_exceeded") == .planLimit)
        #expect(CloudErrorClass(errorCode: "not_signed_in") == .auth)
        #expect(CloudErrorClass(errorCode: "backend_unreachable") == .network)
        #expect(CloudErrorClass(errorCode: "http_503") == .server)
        #expect(CloudErrorClass(errorCode: "vm_not_found") == .client)
        #expect(CloudPlanLimit(errorCode: "vm_memory_requires_plan") == .machineMemory)
        #expect(CloudPlanLimit(errorCode: "vm_not_found") == nil)
    }

    @Test("durations bucket at their boundaries")
    func durationBuckets() {
        #expect(DurationBucket(seconds: -1) == .under1s)
        #expect(DurationBucket(seconds: 0.999) == .under1s)
        #expect(DurationBucket(seconds: 1) == .from1to3s)
        #expect(DurationBucket(seconds: 59) == .from30to60s)
        #expect(DurationBucket(seconds: 7 * 86_400) == .over7d)
    }
}
