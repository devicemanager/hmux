import Foundation

/// Provider that renders with explicit render context.
public protocol HmuxContextualSidebarProvider: HmuxSidebarProvider {
    /// Builds a render model from a sidebar snapshot and render context.
    func render(snapshot: HmuxSidebarProviderSnapshot, context: HmuxSidebarProviderRenderContext) -> HmuxSidebarProviderRenderModel
}
