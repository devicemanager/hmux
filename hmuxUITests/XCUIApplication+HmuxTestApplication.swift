import XCTest

extension XCUIApplication {
    static func hmuxTestApplication() -> XCUIApplication {
        let application = XCUIApplication()
        application.launchEnvironment["HMUX_UI_TEST_PROCESS"] = "1"
        return application
    }
}
