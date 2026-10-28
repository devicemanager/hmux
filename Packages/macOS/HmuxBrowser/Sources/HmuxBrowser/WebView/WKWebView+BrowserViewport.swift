public import AppKit
public import ObjectiveC.runtime
public import WebKit

private final class BrowserViewportWeakHostBox: NSObject {
    weak var value: BrowserViewportHostView?
}

private enum BrowserViewportAssociatedKeys {
    nonisolated(unsafe) static var host: UInt8 = 0
    nonisolated(unsafe) static var externalRenderHostDepth: UInt8 = 0
}

extension WKWebView {
    public var hmuxBrowserViewportHostView: BrowserViewportHostView? {
        get {
            (objc_getAssociatedObject(self, &BrowserViewportAssociatedKeys.host)
                as? BrowserViewportWeakHostBox)?.value
        }
        set {
            if let box = objc_getAssociatedObject(
                self,
                &BrowserViewportAssociatedKeys.host
            ) as? BrowserViewportWeakHostBox {
                box.value = newValue
            } else {
                let box = BrowserViewportWeakHostBox()
                box.value = newValue
                objc_setAssociatedObject(
                    self,
                    &BrowserViewportAssociatedKeys.host,
                    box,
                    .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                )
            }
        }
    }

    public var hmuxBrowserViewportUsesHost: Bool {
        guard let host = hmuxBrowserViewportHostView else { return false }
        return superview === host
    }

    public var hmuxBrowserViewportPresentationView: NSView {
        guard hmuxBrowserViewportUsesHost, let host = hmuxBrowserViewportHostView else {
            return self
        }
        return host
    }

    public var hmuxBrowserViewportAttachmentSuperview: NSView? {
        hmuxBrowserViewportPresentationView.superview
    }

    public var hmuxBrowserViewportAttachmentWindow: NSWindow? {
        hmuxBrowserViewportPresentationView.window ?? window
    }

    public var hmuxBrowserViewportExternalRenderHostIsActive: Bool {
        ((objc_getAssociatedObject(
            self,
            &BrowserViewportAssociatedKeys.externalRenderHostDepth
        ) as? NSNumber)?.intValue ?? 0) > 0
    }

    func hmuxBeginBrowserViewportExternalRenderHost() {
        let depth = (objc_getAssociatedObject(
            self,
            &BrowserViewportAssociatedKeys.externalRenderHostDepth
        ) as? NSNumber)?.intValue ?? 0
        objc_setAssociatedObject(
            self,
            &BrowserViewportAssociatedKeys.externalRenderHostDepth,
            NSNumber(value: depth + 1),
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }

    func hmuxEndBrowserViewportExternalRenderHost() {
        let depth = (objc_getAssociatedObject(
            self,
            &BrowserViewportAssociatedKeys.externalRenderHostDepth
        ) as? NSNumber)?.intValue ?? 0
        let nextDepth = max(0, depth - 1)
        objc_setAssociatedObject(
            self,
            &BrowserViewportAssociatedKeys.externalRenderHostDepth,
            nextDepth > 0 ? NSNumber(value: nextDepth) : nil,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }

    public func hmuxIsManagedByExternalRenderHost(relativeTo expectedSuperview: NSView?) -> Bool {
        hmuxBrowserViewportExternalRenderHostIsActive &&
            hmuxBrowserViewportPresentationView.superview !== expectedSuperview
    }

    public var hmuxBrowserViewportContainerBounds: CGRect? {
        hmuxBrowserViewportAttachmentSuperview?.bounds
    }

    var hmuxBrowserViewportLayoutMode: BrowserViewportLayout.Mode {
        (self as? HmuxWebView)?.browserViewportModel?.viewport == nil ? .native : .emulated
    }

    var hmuxBrowserViewportAutoresizingMask: NSView.AutoresizingMask {
        hmuxBrowserViewportLayoutMode == .native ? [.width, .height] : []
    }

    public func hmuxBrowserViewportLayout(in containerBounds: CGRect) -> BrowserViewportLayout? {
        BrowserViewportLayout(
            containerBounds: containerBounds,
            viewport: (self as? HmuxWebView)?.browserViewportModel?.viewport,
            pageZoom: Double(pageZoom)
        )
    }

    public func hmuxBrowserViewportLayoutMatches(_ containerBounds: CGRect, epsilon: Double = 0.5) -> Bool {
        guard let layout = hmuxBrowserViewportLayout(in: containerBounds) else {
            return false
        }
        if hmuxBrowserViewportUsesHost, let host = hmuxBrowserViewportHostView {
            return host.matches(layout, epsilon: epsilon)
        }
        return Self.hmuxBrowserViewportRect(frame, matches: layout.frame, epsilon: epsilon) &&
            Self.hmuxBrowserViewportRect(bounds, matches: layout.webViewBounds, epsilon: epsilon) &&
            autoresizingMask == hmuxBrowserViewportAutoresizingMask
    }

    @discardableResult
    public func hmuxApplyBrowserViewportLayout(in containerBounds: CGRect) -> BrowserViewportLayout? {
        guard let layout = hmuxBrowserViewportLayout(in: containerBounds) else {
            return nil
        }
        hmuxApplyBrowserViewportLayout(layout)
        return layout
    }

    public func hmuxApplyBrowserViewportLayout(_ layout: BrowserViewportLayout) {
        if hmuxBrowserViewportUsesHost, let host = hmuxBrowserViewportHostView {
            host.apply(layout)
            return
        }
        translatesAutoresizingMaskIntoConstraints = true
        autoresizingMask = hmuxBrowserViewportAutoresizingMask

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if !Self.hmuxBrowserViewportRect(frame, matches: layout.frame) {
            frame = layout.frame
        }
        if !Self.hmuxBrowserViewportRect(bounds, matches: layout.webViewBounds) {
            bounds = layout.webViewBounds
        }
        CATransaction.commit()
    }

    func hmuxApplyRawBrowserViewportGeometry(_ rawBounds: CGRect) {
        translatesAutoresizingMaskIntoConstraints = true
        autoresizingMask = hmuxBrowserViewportAutoresizingMask

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if !Self.hmuxBrowserViewportRect(frame, matches: rawBounds) {
            frame = rawBounds
        }
        if !Self.hmuxBrowserViewportRect(bounds, matches: rawBounds) {
            bounds = rawBounds
        }
        CATransaction.commit()
    }

    @discardableResult
    public func hmuxRestoreIntoBrowserViewportHostIfNeeded() -> Bool {
        hmuxBrowserViewportHostView?.restoreWebViewIfNeeded() ?? false
    }

    @discardableResult
    public func hmuxRestoreIntoBrowserViewportHostAfterExternalGeometryIfSafe() -> Bool {
        hmuxBrowserViewportHostView?.restoreWebViewAfterExternalGeometryIfSafe() ?? false
    }

    private static func hmuxBrowserViewportRect(
        _ lhs: CGRect,
        matches rhs: CGRect,
        epsilon: Double = 0.5
    ) -> Bool {
        abs(lhs.minX - rhs.minX) <= epsilon &&
            abs(lhs.minY - rhs.minY) <= epsilon &&
            abs(lhs.width - rhs.width) <= epsilon &&
            abs(lhs.height - rhs.height) <= epsilon
    }
}
