import AppKit
import HmuxBrowser

extension BrowserPanel {
    @discardableResult
    func setAutomationViewport(
        _ viewport: BrowserViewport?
    ) -> Result<BrowserViewportLayout, BrowserAutomationViewportError> {
        let webView = webView
        guard !webView.hmuxIsElementFullscreenActiveOrTransitioning else {
            return .failure(.elementFullscreen)
        }
        if let host = webView.superview,
           host.browserPortalHasVisibleWebKitCompanionSubview(for: webView) {
            return .failure(.attachedBrowserInspector)
        }
        if viewportHostView.browserPortalHasVisibleWebKitCompanionSubview(for: webView) {
            return .failure(.attachedBrowserInspector)
        }

        let containerBounds = webView.hmuxBrowserViewportContainerBounds
            ?? fallbackAutomationViewportContainerBounds
        guard let layout = BrowserViewportLayout(
            containerBounds: containerBounds,
            viewport: viewport,
            pageZoom: Double(webView.pageZoom)
        ) else {
            let pageZoom = Double(webView.pageZoom)
            let maximumPageZoom = viewport.map {
                BrowserViewportRenderLimits.standard.maximumPageZoom(for: $0)
            } ?? pageZoom
            return .failure(.renderGeometryTooLarge(
                requestedPageZoom: pageZoom,
                maximumPageZoom: maximumPageZoom
            ))
        }

        viewportModel.setViewport(viewport)
        if let webView = webView as? HmuxWebView {
            webView.browserViewportModel = viewportModel
        }
        if viewport != nil {
            _ = webView.hmuxRestoreIntoBrowserViewportHostAfterExternalGeometryIfSafe()
        } else {
            _ = viewportHostView.deactivateWebView(using: layout)
        }
        webView.hmuxApplyBrowserViewportLayout(layout)
        webView.needsLayout = true
        webView.hmuxBrowserViewportPresentationView.needsLayout = true
        webView.hmuxBrowserViewportAttachmentSuperview?.needsLayout = true
        webView.hmuxBrowserViewportAttachmentSuperview?.layoutSubtreeIfNeeded()
        webView.layoutSubtreeIfNeeded()
        BrowserWindowPortalRegistry.refresh(webView: webView, reason: "automationViewport")
        return .success(layout)
    }

    func reapplyAutomationViewportAfterPageZoom() {
        guard !webView.hmuxIsElementFullscreenActiveOrTransitioning,
              let viewport = viewportModel.viewport,
              let containerBounds = webView.hmuxBrowserViewportContainerBounds else {
            return
        }
        guard BrowserViewportRenderLimits.standard.supports(
            viewport: viewport,
            pageZoom: Double(webView.pageZoom)
        ) else {
            return
        }
        if let rawHost = webView.superview,
           rawHost.browserPortalHasVisibleWebKitCompanionSubview(for: webView) {
            if let layout = webView.hmuxBrowserViewportLayout(in: containerBounds) {
                webView.hmuxBrowserViewportHostView?.apply(layout, updateWebView: false)
                webView.bounds = layout.webViewBounds
            }
        } else {
            webView.hmuxApplyBrowserViewportLayout(in: containerBounds)
        }
    }

    @discardableResult
    func reconcileAutomationViewportForElementFullscreen(isActive: Bool) -> Bool {
        if isActive {
            return viewportModel.suspendForExternalGeometry()
        }
        return viewportModel.resumeAfterExternalGeometry() != nil
    }

    func scheduleBrowserViewportHostRestoration(
        reason: String
    ) {
        guard viewportModel.requestedViewport != nil else {
            browserViewportHostRestorationTask?.cancel()
            browserViewportHostRestorationTask = nil
            browserViewportHostRestorationPending = false
            return
        }
        browserViewportHostRestorationPending = true
        browserViewportHostRestorationTask?.cancel()
        let expectedWebView = webView
        browserViewportHostRestorationTask = Task { @MainActor [weak self, weak expectedWebView] in
            await Task.yield()
            guard !Task.isCancelled,
                  let self,
                  let expectedWebView,
                  self.webView === expectedWebView,
                  self.browserViewportHostRestorationPending,
                  self.viewportModel.requestedViewport != nil else {
                return
            }
            self.browserViewportHostRestorationTask = nil
            guard !expectedWebView.hmuxIsElementFullscreenActiveOrTransitioning else {
                return
            }

            _ = expectedWebView.hmuxRestoreIntoBrowserViewportHostAfterExternalGeometryIfSafe()
            guard expectedWebView.hmuxBrowserViewportUsesHost else { return }

            self.browserViewportHostRestorationPending = false
            self.reapplyAutomationViewportAfterPageZoom()
            BrowserWindowPortalRegistry.refresh(
                webView: expectedWebView,
                reason: "viewportHostRestore.\(reason)"
            )
        }
    }

    @discardableResult
    func resetAutomationViewportForAttachedBrowserInspector() -> Bool {
        let containerBounds = webView.hmuxBrowserViewportContainerBounds ?? webView.frame
        guard let nativeLayout = viewportModel.resetForAttachedInspector(
            containerBounds: containerBounds,
            pageZoom: Double(webView.pageZoom)
        ) else {
            return false
        }
        webView.translatesAutoresizingMaskIntoConstraints = true
        webView.autoresizingMask = [.width, .height]
        webView.hmuxBrowserViewportHostView?.apply(nativeLayout, updateWebView: false)
        BrowserWindowPortalRegistry.refresh(
            webView: webView,
            reason: "attachedInspectorResetAutomationViewport"
        )
        return true
    }

    func visualAutomationViewportSize() -> NSSize {
        if let viewport = viewportModel.viewport {
            return viewport.size
        }
        let candidates = [
            webView.bounds.size,
            webView.frame.size,
            webView.window?.contentView?.bounds.size ?? .zero,
        ]
        for candidate in candidates where candidate.width > 1 && candidate.height > 1 {
            return NSSize(
                width: min(max(candidate.width, 1), 4096),
                height: min(max(candidate.height, 1), 4096)
            )
        }
        return NSSize(width: 1280, height: 720)
    }

    private var fallbackAutomationViewportContainerBounds: CGRect {
        let candidates = [webView.frame.size, webView.bounds.size]
        let size = candidates.first(where: { $0.width > 1 && $0.height > 1 })
            ?? CGSize(width: 800, height: 600)
        return CGRect(origin: .zero, size: size)
    }
}
