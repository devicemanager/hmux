import Foundation
import Testing

#if canImport(hmux_DEV)
@testable import hmux_DEV
#elseif canImport(hmux)
@testable import hmux
#endif

/// Regression coverage for authoritative pane captures containing blank rows.
@Suite struct RemoteTmuxControlParserBlankLineTests {
    @Test func commandBlockPreservesInteriorBlankLineAcrossTransportChunks() {
        var parser = RemoteTmuxControlStreamParser()
        var messages: [RemoteTmuxControlMessage] = []

        for chunk in [
            "%begin 1700000000 7 1\r\nfirst row\r\n\r",
            "\nthird row\r\n%end 1700000000 7 1\r",
            "\n",
        ] {
            messages.append(contentsOf: parser.feed(Data(chunk.utf8)))
        }

        #expect(messages == [
            .commandResult(
                commandNumber: 7,
                lines: ["first row", "", "third row"],
                isError: false
            )
        ])
    }
}
