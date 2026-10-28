import AppKit
import HmuxFoundation
import SwiftUI

struct AcknowledgmentsView: View {
    private let content = AboutLicenseContent(bundle: .main).load()

    var body: some View {
        ScrollView {
            Text(content)
                .hmuxFont(.body, design: .monospaced)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
    }
}
