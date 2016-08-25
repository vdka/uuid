import XCTest
@testable import uuid

class uuidTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        XCTAssertEqual(uuid().text, "Hello, World!")
    }


    static var allTests : [(String, (uuidTests) -> () throws -> Void)] {
        return [
            ("testExample", testExample),
        ]
    }
}
