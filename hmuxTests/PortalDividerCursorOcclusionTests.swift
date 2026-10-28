import Testing

#if canImport(hmux_DEV)
@testable import hmux_DEV
#elseif canImport(hmux)
@testable import hmux
#endif

@MainActor
@Suite struct PortalDividerCursorOcclusionTests {
    @Test func sameTopmostWindowMayAssertCursor() {
        let occlusion = PortalDividerCursorOcclusion { _ in 10 }

        #expect(occlusion.mayAssertDividerCursor(screenPoint: .zero, windowNumber: 10))
    }

    @Test func overlappingWindowSuppressesCursor() {
        let occlusion = PortalDividerCursorOcclusion { _ in 11 }

        #expect(!occlusion.mayAssertDividerCursor(screenPoint: .zero, windowNumber: 10))
    }

    @Test func nilPointerWindowSuppressesCursor() {
        let occlusion = PortalDividerCursorOcclusion { _ in nil }

        #expect(!occlusion.mayAssertDividerCursor(screenPoint: .zero, windowNumber: 10))
    }

    @Test func nilHostWindowSuppressesCursor() {
        let occlusion = PortalDividerCursorOcclusion { _ in 10 }

        #expect(!occlusion.mayAssertDividerCursor(in: nil))
    }
}
