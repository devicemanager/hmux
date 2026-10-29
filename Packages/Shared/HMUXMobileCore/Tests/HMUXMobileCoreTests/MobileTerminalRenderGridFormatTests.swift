import Foundation
import Testing
@testable import HMUXMobileCore

/// libghostty's `ghostty_surface_render_grid_json` writes this label
/// (`ghostty/src/apprt/embedded.zig`). It is a wire identifier shared with the
/// Ghostty fork and upstream, not product branding, so the decoder must accept
/// exactly this value.
private let libghosttyRenderGridFormat = "cmux.render-grid.v1"

@Test func decodesRenderGridLabeledAsLibghosttyWritesIt() throws {
    let json = Data(
        """
        {
          "format": "\(libghosttyRenderGridFormat)",
          "surface_id": "format-label",
          "state_seq": 1,
          "columns": 4,
          "rows": 1,
          "full": true,
          "row_spans": [{
            "row": 0,
            "column": 0,
            "style_id": 0,
            "cell_width": 4,
            "text": "test"
          }]
        }
        """.utf8
    )

    let frame = try MobileTerminalRenderGridFrame.decode(json)

    #expect(frame.format == libghosttyRenderGridFormat)
    #expect(frame.rowSpans.map(\.text) == ["test"])
}
