import XCTest

#if canImport(hmux_DEV)
@testable import hmux_DEV
#elseif canImport(hmux)
@testable import hmux
#endif

final class CLICommandSuggestionDerivationTests: XCTestCase {
    func testUnknownCommandSuggestsNearestDeclaredCommand() throws {
        let cliPath = try BundledCLITestSupport.bundledCLIPath(for: Self.self)
        let result = try runCLI(cliPath, arguments: ["list-workspace"], environment: [:])

        XCTAssertTrue(
            result.stderr.contains("Did you mean 'list-workspaces'?"),
            "typo suggestions must come from the declared tree, not a stale literal list"
        )
        XCTAssertEqual(result.exitCode, 2)
    }

    func testHiddenCommandsAreNeverSuggested() throws {
        let cliPath = try BundledCLITestSupport.bundledCLIPath(for: Self.self)
        let result = try runCLI(cliPath, arguments: ["_internal_flags"], environment: [:])

        XCTAssertTrue(
            result.stderr.contains("Unknown command '_internal_flags'."),
            "the single-underscore typo must reach the unknown-command path"
        )
        XCTAssertEqual(result.exitCode, 2)
        XCTAssertFalse(
            result.stderr.contains("__internal_flags"),
            "hidden __-prefixed commands must stay out of user-facing suggestions"
        )
    }
}
