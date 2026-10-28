import Testing

#if canImport(hmux_DEV)
@testable import hmux_DEV
#elseif canImport(hmux)
@testable import hmux
#endif

@MainActor
@Suite struct SidebarResizerOcclusionResolverTests {
    @Test func draggingBypassesPointerWindowGate() {
        var queryCount = 0
        let resolver = SidebarResizerOcclusionResolver { _ in
            queryCount += 1
            return 11
        }

        #expect(
            resolver.bandMayActivate(
                isDragging: true,
                isInDividerBand: false,
                screenPoint: .zero,
                observedWindowNumber: 10
            )
        )
        #expect(queryCount == 0)
    }

    @Test func inBandSameWindowActivates() {
        let resolver = SidebarResizerOcclusionResolver { _ in 10 }

        #expect(
            resolver.bandMayActivate(
                isDragging: false,
                isInDividerBand: true,
                screenPoint: .zero,
                observedWindowNumber: 10
            )
        )
    }

    @Test func inBandDifferentWindowDoesNotActivate() {
        let resolver = SidebarResizerOcclusionResolver { _ in 11 }

        #expect(
            !resolver.bandMayActivate(
                isDragging: false,
                isInDividerBand: true,
                screenPoint: .zero,
                observedWindowNumber: 10
            )
        )
    }

    @Test func inBandNilPointerWindowDoesNotActivate() {
        let resolver = SidebarResizerOcclusionResolver { _ in nil }

        #expect(
            !resolver.bandMayActivate(
                isDragging: false,
                isInDividerBand: true,
                screenPoint: .zero,
                observedWindowNumber: 10
            )
        )
    }

    @Test func outOfBandDoesNotActivate() {
        var queryCount = 0
        let resolver = SidebarResizerOcclusionResolver { _ in
            queryCount += 1
            return 10
        }

        #expect(
            !resolver.bandMayActivate(
                isDragging: false,
                isInDividerBand: false,
                screenPoint: .zero,
                observedWindowNumber: 10
            )
        )
        #expect(queryCount == 0)
    }
}
