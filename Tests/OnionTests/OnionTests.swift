import XCTest
@testable import Onion

final class OnionTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(Onion().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
