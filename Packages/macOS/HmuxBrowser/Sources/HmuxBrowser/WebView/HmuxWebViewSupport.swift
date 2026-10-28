public import AppKit
public import WebKit

extension WKWebView {
    public func hmuxOwnsKeyEvent(_ event: NSEvent) -> Bool {
        guard let eventWindow = event.window ?? window,
              eventWindow === window,
              let responder = eventWindow.firstResponder else { return false }
        if responder === self { return true }
        return (responder as? NSView)?.isDescendant(of: self) == true
    }

    nonisolated private static var hmuxSetPageMutedSelector: Selector {
        NSSelectorFromString("_setPageMuted:")
    }

    nonisolated private static var hmuxMediaMutedStateAudio: Int {
        1 << 0
    }

    @discardableResult
    public func hmuxSetPageAudioMuted(_ muted: Bool) -> Bool {
        let selector = Self.hmuxSetPageMutedSelector
        guard responds(to: selector),
              let implementation = method(for: selector) else {
            return false
        }

        typealias SetPageMutedFunction = @convention(c) (AnyObject, Selector, Int) -> Void
        let function = unsafeBitCast(implementation, to: SetPageMutedFunction.self)
        function(self, selector, muted ? Self.hmuxMediaMutedStateAudio : 0)
        return true
    }

    /// Whether the page is capturing the camera, microphone, a display or
    /// system audio, counting muted capture as capture.
    public var hmuxIsCapturingMedia: Bool {
        cameraCaptureState != .none
            || microphoneCaptureState != .none
            || hmuxCaptureState(selectorName: "_displayCaptureState")
            || hmuxCaptureState(selectorName: "_systemAudioCaptureState")
    }

    /// Reads a capture state WebKit exposes only as SPI, such as the display
    /// capture behind screen sharing. Zero means none.
    private func hmuxCaptureState(selectorName: String) -> Bool {
        let selector = NSSelectorFromString(selectorName)
        guard responds(to: selector),
              let implementation = method(for: selector) else {
            return true
        }

        typealias CaptureStateFunction = @convention(c) (AnyObject, Selector) -> Int
        let function = unsafeBitCast(implementation, to: CaptureStateFunction.self)
        return function(self, selector) != 0
    }

    public var hmuxIsElementFullscreenActiveOrTransitioning: Bool {
        switch fullscreenState {
        case .notInFullscreen:
            return false
        case .enteringFullscreen, .inFullscreen, .exitingFullscreen:
            return true
        @unknown default:
            return true
        }
    }

    public func hmuxIsManagedByExternalFullscreenWindow(relativeTo expectedWindow: NSWindow?) -> Bool {
        guard hmuxIsElementFullscreenActiveOrTransitioning else { return false }
        guard let expectedWindow else { return true }
        return window !== expectedWindow
    }
}
