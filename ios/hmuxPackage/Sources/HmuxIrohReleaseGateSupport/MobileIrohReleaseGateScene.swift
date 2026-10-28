#if os(iOS) && DEBUG
import HMUXMobileCore
import HmuxIrohTransport
import SwiftUI
public import hmuxFeature

/// Debug-only wrapper that substitutes the isolated Iroh release gate while
/// preserving the production root scene and environment for ordinary launches.
@MainActor
public struct MobileIrohReleaseGateScene: View {
    private let uiProbe: MobileReleaseGateUIProbe
    private let root: HMUXMobileRootScene
    private let irx: MobileIrxRuntimeComposition
    private let settingsController: any CmxIrohSettingsControlling

    public init(
        uiProbe: MobileReleaseGateUIProbe,
        root: HMUXMobileRootScene,
        irx: MobileIrxRuntimeComposition,
        settingsController: any CmxIrohSettingsControlling
    ) {
        self.uiProbe = uiProbe
        self.root = root
        self.irx = irx
        self.settingsController = settingsController
    }

    @ViewBuilder
    public var body: some View {
        if let configuration = MobileIrohReleaseGateRunner.Configuration.current() {
            root.applyingRootEnvironment(
                to: MobileIrohReleaseGateHostView(
                    uiProbe: uiProbe,
                    store: root.makeStore(),
                    configuration: configuration,
                    onboardingStore: root.onboardingStore,
                    signOutHook: root.signOutHook,
                    settingsController: settingsController,
                    endpointIdentity: { await irx.releaseGateEndpointIdentity() },
                    relayCredentialExpiry: {
                        await irx.releaseGateRelayCredentialExpiry()
                    }
                )
            )
        } else {
            root
        }
    }
}
#endif
