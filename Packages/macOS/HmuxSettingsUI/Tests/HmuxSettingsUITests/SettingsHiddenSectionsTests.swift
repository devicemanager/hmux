import Testing
@testable import HmuxSettingsUI

/// Sections the settings window hides outright instead of showing disabled:
/// Cloud without a Cloud host, and Networking (Iroh relays) when Iroh is
/// turned off, as in a local-only build.
@MainActor
@Suite("Settings hidden sections")
struct SettingsHiddenSectionsTests {
    @Test func everySectionShowsWhenCloudAndIrohAreAvailable() {
        let hidden = SettingsWindowRoot.hiddenSections(cloudAvailable: true, irohNetworkingDisabled: false)
        #expect(hidden.isEmpty)
        #expect(SettingsWindowRoot.mountOrder(hidden: hidden) == SettingsSectionMountModel.displayOrder)
    }

    @Test func disabledIrohHidesNetworking() {
        let hidden = SettingsWindowRoot.hiddenSections(cloudAvailable: true, irohNetworkingDisabled: true)
        #expect(hidden == [.networking])
        #expect(!SettingsWindowRoot.mountOrder(hidden: hidden).contains(.networking))
    }

    @Test func localOnlyBuildHidesCloudAndNetworkingButKeepsDevicesAndMobile() {
        let hidden = SettingsWindowRoot.hiddenSections(cloudAvailable: false, irohNetworkingDisabled: true)
        #expect(hidden == [.cloudMachines, .networking])
        let order = SettingsWindowRoot.mountOrder(hidden: hidden)
        #expect(order.contains(.mobile))
        #expect(order.contains(.computers))
    }
}
