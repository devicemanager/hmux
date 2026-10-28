import Foundation
import Testing

#if canImport(hmux_DEV)
@testable import hmux_DEV
#elseif canImport(hmux)
@testable import hmux
#endif

@Suite("About licenses resources")
struct AboutLicensesResourceTests {
    @Test("The project GPL is available to the About licenses UI")
    func projectLicenseIsBundled() throws {
        let url = try #require(Bundle.main.url(forResource: "LICENSE", withExtension: nil))
        let contents = try String(contentsOf: url, encoding: .utf8)

        #expect(contents.contains("Copyright (c) 2024-present Manaflow, Inc."))
        #expect(contents.contains("GNU GENERAL PUBLIC LICENSE"))
        #expect(contents.contains("Version 3, 29 June 2007"))
    }

    @Test("The About licenses content includes the project GPL and source directions")
    func aboutContentIncludesProjectLicenseAndSourceDirections() throws {
        let licenseContent = AboutLicenseContent(bundle: .main)
        let contents = licenseContent.load()

        #expect(contents.contains("Copyright (c) 2024-present Manaflow, Inc."))
        #expect(contents.contains("GNU GENERAL PUBLIC LICENSE"))
        #expect(contents.contains(licenseContent.repositoryURL.absoluteString))
        #expect(contents.contains(licenseContent.correspondingSourceURL().absoluteString))
    }

    @Test("Stable builds link corresponding source to their exact version tag")
    func stableBuildUsesVersionTag() {
        let repositoryURL = URL(string: "https://example.com/hmux-source")!
        let url = AboutLicenseContent(
            bundle: .main,
            repositoryURL: repositoryURL
        ).correspondingSourceURL(
            version: "0.64.19",
            bundleIdentifier: "com.hmuxterm.app",
            commit: "abcdef123"
        )

        #expect(url.absoluteString == "https://example.com/hmux-source/tree/v0.64.19")
    }

    @Test(
        "Non-stable builds link corresponding source to their commit",
        arguments: ["com.hmuxterm.app.debug.licpkg", "com.hmuxterm.app.nightly", "com.hmuxterm.app.rc"]
    )
    func nonStableBuildUsesCommit(bundleIdentifier: String) {
        let url = AboutLicenseContent(bundle: .main).correspondingSourceURL(
            version: "0.64.19",
            bundleIdentifier: bundleIdentifier,
            commit: "abcdef123"
        )

        #expect(url.absoluteString == "https://github.com/manaflow-ai/cmux/tree/abcdef123")
    }
}
