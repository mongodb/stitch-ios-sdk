import XCTest
@testable import MockUtils

final class MockUtilsTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(MockUtils().text, "Hello, World!")
    }


    static var allTests = [
        ("testExample", testExample),
    ]
}
