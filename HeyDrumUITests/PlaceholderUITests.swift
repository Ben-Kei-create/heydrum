import XCTest

final class PlaceholderUITests: XCTestCase {
    func testLaunches() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest"]
        app.launch()
        XCTAssertTrue(app.staticTexts["ヘイドラム"].waitForExistence(timeout: 5))
    }
}
