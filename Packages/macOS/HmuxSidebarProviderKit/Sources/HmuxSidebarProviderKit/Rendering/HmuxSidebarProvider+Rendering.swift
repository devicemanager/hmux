import Foundation

public extension HmuxSidebarProvider {
    /// Builds the default empty render model for providers that do not implement rendering.
    func render(snapshot: HmuxSidebarProviderSnapshot) -> HmuxSidebarProviderRenderModel {
        HmuxSidebarProviderRenderModel(
            providerId: descriptor.id,
            snapshotSequence: snapshot.sequence,
            sections: []
        )
    }

    /// Builds a render model using contextual rendering when available.
    func render(
        snapshot: HmuxSidebarProviderSnapshot,
        context: HmuxSidebarProviderRenderContext
    ) -> HmuxSidebarProviderRenderModel {
        render(snapshot: snapshot)
    }
}
