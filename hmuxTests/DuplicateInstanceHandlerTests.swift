import Foundation
import Testing

#if canImport(hmux_DEV)
@testable import hmux_DEV
#elseif canImport(hmux)
@testable import hmux
#endif

@Suite("Duplicate instance handling")
struct DuplicateInstanceHandlerTests {
    @Test("only the hmux executable is considered a duplicate")
    func onlyHmuxExecutableMatches() {
        let app = URL(fileURLWithPath: "/Applications/hmux.app/Contents/MacOS/hmux")
        let cli = URL(fileURLWithPath: "/Applications/hmux.app/Contents/Resources/bin/hmux")
        #expect(!AppDelegate.isDuplicateApplicationExecutable(nil, mainExecutableURL: app))
        #expect(!AppDelegate.isDuplicateApplicationExecutable(app, mainExecutableURL: nil))
        let helper = URL(fileURLWithPath: "/usr/bin/osascript")

        #expect(AppDelegate.isDuplicateApplicationExecutable(app, mainExecutableURL: app))
        #expect(!AppDelegate.isDuplicateApplicationExecutable(cli, mainExecutableURL: app))
        #expect(!AppDelegate.isDuplicateApplicationExecutable(helper, mainExecutableURL: app))
    }
}
