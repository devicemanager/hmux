public import SwiftUI

/// SwiftUI bridge for appearance-resolved AppKit icons.
@MainActor
public struct HmuxResolvedIconImage: NSViewRepresentable {
    public let request: HmuxResolvedIconRequest?

    /// Creates a SwiftUI icon backed by ``HmuxResolvedIconImageView``.
    public init(request: HmuxResolvedIconRequest?) {
        self.request = request
    }

    public func makeNSView(context: Context) -> HmuxResolvedIconImageView {
        HmuxResolvedIconImageView(frame: .zero)
    }

    public func updateNSView(_ nsView: HmuxResolvedIconImageView, context: Context) {
        nsView.apply(request)
    }
}
