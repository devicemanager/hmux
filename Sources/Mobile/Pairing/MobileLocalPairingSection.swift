import AppKit
import CMUXMobileCore
import CmuxFoundation
import CoreImage.CIFilterBuiltins
import SwiftUI

/// Account-free pairing for a local-only iPhone app.
///
/// Shows a single-use `cmux-local://` QR code that names this Mac's Tailscale
/// addresses. The phone redeems it once for its own device key, so neither
/// side needs a cmux account, relay, or cloud service.
struct MobileLocalPairingSection: View {
    @State private var payload: CmxLocalPairingPayload?
    @State private var errorMessage: String?
    @State private var now = Date()

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(
                localized: "mobile.localPairing.heading",
                defaultValue: "Pair without an account"
            ))
                .cmuxFont(.headline)
            Text(String(
                localized: "mobile.localPairing.body",
                defaultValue: "For a private iPhone build that connects only over Tailscale. Each code works once and expires after five minutes."
            ))
                .cmuxFont(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let payload, payload.expiresAt > now {
                codeView(payload)
            } else {
                Button(String(
                    localized: "mobile.localPairing.create",
                    defaultValue: "Show Pairing Code"
                )) {
                    issueCode()
                }
            }
            if let errorMessage {
                Text(errorMessage)
                    .cmuxFont(.callout)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onReceive(ticker) { now = $0 }
    }

    private func codeView(_ payload: CmxLocalPairingPayload) -> some View {
        HStack(alignment: .top, spacing: 16) {
            if let image = Self.qrImage(for: payload.url.absoluteString) {
                Image(nsImage: image)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 180, height: 180)
                    .accessibilityLabel(String(
                        localized: "mobile.localPairing.qrAccessibility",
                        defaultValue: "Local pairing QR code"
                    ))
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(String(
                    localized: "mobile.localPairing.scanHint",
                    defaultValue: "Scan this code from the iPhone app's Add Computer screen."
                ))
                    .fixedSize(horizontal: false, vertical: true)
                Text(payload.hosts.map { "\($0):\(payload.port)" }.joined(separator: "\n"))
                    .cmuxFont(.callout, design: .monospaced)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Text(expiryText(payload.expiresAt))
                    .cmuxFont(.callout, monospacedDigit: true)
                    .foregroundStyle(.secondary)
                HStack {
                    Button(String(
                        localized: "mobile.localPairing.copy",
                        defaultValue: "Copy Code Link"
                    )) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(payload.url.absoluteString, forType: .string)
                    }
                    Button(String(
                        localized: "mobile.localPairing.newCode",
                        defaultValue: "New Code"
                    )) {
                        issueCode()
                    }
                }
            }
        }
    }

    private func expiryText(_ expiresAt: Date) -> String {
        let remaining = max(0, Int(expiresAt.timeIntervalSince(now)))
        let format = String(
            localized: "mobile.localPairing.expiresIn",
            defaultValue: "Expires in %d:%02d"
        )
        return String(format: format, remaining / 60, remaining % 60)
    }

    private func issueCode() {
        switch MobileHostService.shared.issueLocalPairingPayload() {
        case let .success(issued):
            payload = issued
            errorMessage = nil
            now = Date()
        case .failure(.listenerNotRunning):
            payload = nil
            errorMessage = String(
                localized: "mobile.localPairing.listenerOff",
                defaultValue: "The Tailscale pairing listener is not running. Turn on iOS pairing in Settings > Mobile."
            )
        case .failure(.noTailscaleAddress):
            payload = nil
            errorMessage = String(
                localized: "mobile.localPairing.noTailscale",
                defaultValue: "This Mac has no Tailscale address. Connect Tailscale and try again."
            )
        }
    }

    private static func qrImage(for string: String) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?
            .transformed(by: CGAffineTransform(scaleX: 8, y: 8)) else { return nil }
        let representation = NSCIImageRep(ciImage: output)
        let image = NSImage(size: representation.size)
        image.addRepresentation(representation)
        return image
    }
}
