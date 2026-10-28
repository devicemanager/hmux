import Foundation
import HmuxFoundation
import HmuxTerminalCore

// HmuxSurfaceConfigTemplate and the surface runtime probes moved to
// HmuxTerminalCore (SurfaceValues/HmuxSurfaceConfigTemplate.swift and
// Interop/GhosttySurfaceRuntimeProbe.swift). The legacy free-function names
// below are shims forwarding existing app callers to the probe.

typealias HmuxSurfaceConfigTemplate = HmuxTerminalCore.HmuxSurfaceConfigTemplate

func hmuxSurfaceContextName(_ context: ghostty_surface_context_e) -> String {
    GhosttySurfaceRuntimeProbe.contextName(context)
}

func hmuxSurfacePointerAppearsLive(_ surface: ghostty_surface_t) -> Bool {
    GhosttySurfaceRuntimeProbe.surfacePointerAppearsLive(surface)
}

@MainActor
func hmuxCurrentSurfaceFontSizePoints(_ surface: ghostty_surface_t) -> Float? {
    GhosttySurfaceRuntimeProbe.currentSurfaceFontSizePoints(surface)
}

@MainActor
func hmuxInheritedSurfaceConfig(
    sourceSurface: ghostty_surface_t,
    context: ghostty_surface_context_e
) -> HmuxSurfaceConfigTemplate {
    let inherited = ghostty_surface_inherited_config(sourceSurface, context)
    let percent = GlobalFontMagnification.storedPercent
    var config = HmuxSurfaceConfigTemplate(
        cConfig: inherited,
        globalFontMagnificationPercent: percent
    )

    // Capture runtime zoom for inheritance, even when Ghostty's inherit-font-size
    // config is disabled, without claiming surface-local ownership.
    let runtimePoints = hmuxCurrentSurfaceFontSizePoints(sourceSurface)
    if let points = runtimePoints {
        config.setFontSize(
            HmuxSurfaceConfigTemplate.baseFontSize(
                fromRuntimePoints: points,
                percent: percent
            ),
            isExplicitOverride: false
        )
    }

#if DEBUG
    let inheritedText = String(format: "%.2f", inherited.font_size)
    let runtimeText = runtimePoints.map { String(format: "%.2f", $0) } ?? "nil"
    let finalText = String(format: "%.2f", config.fontSize)
    hmuxDebugLog(
        "zoom.inherit context=\(hmuxSurfaceContextName(context)) " +
        "inherited=\(inheritedText) runtime=\(runtimeText) final=\(finalText)"
    )
#endif

    return config
}
