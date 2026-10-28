import HmuxSurfaceCatalogModel
import Foundation

@MainActor
extension HmuxTuiSurfaceProvider {
    /// A committed terminal retained until the canonical graph reaches its receipt.
    struct PendingRemoteCreation {
        var resource: SurfaceResource
        var receipt: CloudVMCursor?
        let tabID: String?
    }
}
