import XCTest
@testable import StitchCore

class OperationDispatcherUnitTests: XCTestCase {

    var dispatcher: OperationDispatcher!

    override func setUp() {
        super.setUp()
        self.dispatcher = OperationDispatcher.init(withDispatchQueue: DispatchQueue.global())
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    private class DivideByZeroError: Error { }
    private class ArbitraryError: Error { }

    func sampleDivision(numerator: Int, denominator: Int) throws -> Int {
        guard denominator != 0 else {
            throw DivideByZeroError.init()
        }

        return numerator / denominator
    }

    func sampleNoop(shouldThrow: Bool) throws {
        guard !shouldThrow else {
            throw ArbitraryError.init()
        }

        return
    }

    func testSuccessfulDispatch() {
        let expectation = XCTestExpectation.init()

        dispatcher.run(withCompletionHandler: { (result: Int?, error: Error?) in
            XCTAssert(result == 3)
            XCTAssertNil(error)
            expectation.fulfill()
        }, {
            return try self.sampleDivision(numerator: 6, denominator: 2)
        })

        wait(for: [expectation], timeout: defaultTimeoutSeconds)
    }

    func testThrowingDispatch() {
        let expectation = XCTestExpectation.init()

        dispatcher.run(withCompletionHandler: { (result: Int?, error: Error?) in
            XCTAssertNil(result)
            XCTAssert(error is DivideByZeroError)
            expectation.fulfill()
        }, {
            return try self.sampleDivision(numerator: 6, denominator: 0)
        })

        wait(for: [expectation], timeout: defaultTimeoutSeconds)
    }

    func testSuccessfulVoidDispatch() {
        let expectation = XCTestExpectation.init()

        dispatcher.run(withCompletionHandler: { (error: Error?) in
            XCTAssertNil(error)
            expectation.fulfill()
        }, {
            return try self.sampleNoop(shouldThrow: false)
        })

        wait(for: [expectation], timeout: defaultTimeoutSeconds)
    }

    func testThrowingVoidDispatch() {
        let expectation = XCTestExpectation.init()

        dispatcher.run(withCompletionHandler: { (error: Error?) in
            XCTAssert(error is ArbitraryError)
            expectation.fulfill()
        }, {
            return try self.sampleNoop(shouldThrow: true)
        })

        wait(for: [expectation], timeout: defaultTimeoutSeconds)
    }
}
