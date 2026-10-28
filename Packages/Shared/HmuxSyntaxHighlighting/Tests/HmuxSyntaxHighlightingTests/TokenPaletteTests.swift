import HmuxSyntaxHighlighting
import Testing

@Suite("Hmux token palette")
struct TokenPaletteTests {
    @Test("Dark keywords use published product blue")
    func darkKeywordIsProductBlue() {
        #expect(TokenPalette.hmuxDark.keyword.hexString == "#0091FF")
        #expect(TokenTheme.dark.palette.keyword == TokenPalette.hmuxDark.keyword)
    }

    @Test("Light keywords use product-blue-on-foreground")
    func lightKeywordIsReadableProductBlue() {
        #expect(TokenPalette.hmuxLight.keyword.hexString == "#006DC1")
        #expect(TokenPalette.hmuxLight.type.hexString == "#0073D9")
        #expect(TokenPalette.hmuxLight.regexp.hexString == "#0088FF")
        #expect(TokenTheme.light.palette.keyword == TokenPalette.hmuxLight.keyword)
    }

    @Test("Surfaces keep brand neutrals")
    func neutralsMatchMarketingTokens() {
        #expect(TokenPalette.hmuxDark.foreground.hexString == "#EDEDED")
        #expect(TokenPalette.hmuxLight.foreground.hexString == "#171717")
        #expect(TokenPalette.hmuxLight.comment.hexString == "#737373")
    }

    @Test("Parses hash and bare hex")
    func tokenColorParsesHex() throws {
        let hashed = try #require(TokenColor(hex: "#0091ff"))
        let bare = try #require(TokenColor(hex: "0091FF"))
        #expect(hashed == bare)
        #expect(hashed.hexKey == "0091FF")
        #expect(TokenColor(hex: "nope") == nil)
    }
}
