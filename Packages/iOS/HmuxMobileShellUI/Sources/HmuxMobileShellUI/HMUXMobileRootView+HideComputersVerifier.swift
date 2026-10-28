import HmuxMobileShell
import SwiftUI

extension HMUXMobileRootView {
    var shouldShowHideComputersVerifier: Bool {
        #if os(iOS) && DEBUG
        return MobileHideComputersVerifier().isEnabled
        #else
        return false
        #endif
    }

    @ViewBuilder var hideComputersVerifier: some View {
        #if os(iOS) && DEBUG
        HideComputersVerifierView()
        #else
        EmptyView()
        #endif
    }
}
