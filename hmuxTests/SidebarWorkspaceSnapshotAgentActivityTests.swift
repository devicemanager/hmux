import Foundation
import HmuxSidebar
import Testing

#if canImport(hmux_DEV)
@testable import hmux_DEV
#elseif canImport(hmux)
@testable import hmux
#endif

extension SidebarWorkspaceSnapshotTests {
    @MainActor
    @Test func workspaceAgentSpinnerFeatureFlagDefaultsOff() throws {
        let definition = try #require(HmuxFeatureFlags.allFlags.first {
            $0.key == "sidebar-workspace-agent-spinner-experiment"
        })
        let suiteName = "hmux.feature.flags.sidebar-workspace-agent-spinner.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let flags = HmuxFeatureFlags(defaults: defaults, remoteFlagValueProvider: { _ in nil })

        #expect(!flags.effectiveValue(for: definition))
    }

    @Test func presentationKeyChangesWhenAgentActivityVisibilityChanges() {
        let hidden = Self.presentationKey(showsAgentActivity: false)
        let visible = Self.presentationKey(showsAgentActivity: true)

        #expect(hidden != visible)
        #expect(!hidden.showsAgentActivity)
        #expect(visible.showsAgentActivity)
    }

    @Test func disabledSpinnerDoesNotReadAgentLifecycleStates() {
        var didReadAgentLifecycleStates = false
        let agentLifecycleStates: () -> [UUID: [String: AgentHibernationLifecycleState]] = {
            didReadAgentLifecycleStates = true
            return [
                UUID(): [
                    "codex": .running,
                    "claude_code": .running,
                ],
            ]
        }

        let count = SidebarAgentActivitySummary.visibleActiveCodingAgentCount(
            showsAgentActivity: false,
            statesByPanelId: agentLifecycleStates()
        )

        #expect(count == 0)
        #expect(!didReadAgentLifecycleStates)
    }
}
