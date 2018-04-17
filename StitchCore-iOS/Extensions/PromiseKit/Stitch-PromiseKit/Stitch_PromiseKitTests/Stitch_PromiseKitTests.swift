import XCTest
@testable import Stitch_PromiseKit
import PromiseKit

class Stitch_PromiseKitTests: XCTestCase {
    func testAdapterFulfilled() {
        let exp = expectation(description: "fulfilled")

        Promise<Int> { seal in
            adapter(seal)(1, nil)
        }.done { int in
            XCTAssertEqual(int, 1)
            exp.fulfill()
        }.catch { err in
            XCTFail()
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5)
    }

    func testAdapterFailed() {
        let exp = expectation(description: "failed")

        Promise<Int> { seal in
            adapter(seal)(nil, NSError.init(domain: "failure", code: 42, userInfo: nil))
        }.done { int in
            XCTFail()
            exp.fulfill()
        }.catch { err in
            XCTAssertEqual((err as NSError).code, 42)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5)
    }

    func testAdapterVoidFulfilled() {
        let exp = expectation(description: "fulfilled")

        Promise<Void> { seal in
            adapter(seal)(nil)
        }.done { void in
            exp.fulfill()
        }.catch { err in
            XCTFail()
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5)
    }

    func testAdapterVoidFailed() {
        let exp = expectation(description: "failed")

        Promise<Void> { seal in
            adapter(seal)(NSError.init(domain: "failure", code: 42, userInfo: nil))
        }.done { int in
            XCTFail()
            exp.fulfill()
        }.catch { err in
            XCTAssertEqual((err as NSError).code, 42)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5)
    }
}
