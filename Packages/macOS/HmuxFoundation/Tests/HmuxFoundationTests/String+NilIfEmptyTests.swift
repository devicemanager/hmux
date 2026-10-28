import Testing

@testable import HmuxFoundation

@Suite struct StringNilIfEmptyTests {
    @Test func emptyStringBecomesNil() {
        #expect("".nilIfEmpty == nil)
    }

    @Test func nonEmptyStringPassesThrough() {
        #expect("hmux".nilIfEmpty == "hmux")
    }

    @Test func whitespaceIsNotEmpty() {
        // nilIfEmpty only checks isEmpty; a space is non-empty and passes through.
        #expect(" ".nilIfEmpty == " ")
    }
}
