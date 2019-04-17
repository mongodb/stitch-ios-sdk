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

        dispatcher.run(withCompletionHandler: { (result: StitchResult<Int>) in
            switch result {
            case .success(let result):
                XCTAssertTrue(result == 3)
            case .failure:
                XCTFail("unexpected error")
            }

            expectation.fulfill()
        }, {
            return try self.sampleDivision(numerator: 6, denominator: 2)
        })

        wait(for: [expectation], timeout: defaultTimeoutSeconds)
    }

    func testThrowingDispatch() {
        let expectation = XCTestExpectation.init()

        dispatcher.run(withCompletionHandler: { (result: StitchResult<Int>) in
            switch result {
            case .success:
                XCTFail("expected an error and none was thrown")
            case .failure(let error):
                guard case .requestErrorFull(let underlyingError, let errorCode) = error else {
                    XCTFail("wrong error type")
                    return
                }
                XCTAssertEqual(StitchRequestErrorCode.unknownError, errorCode)
                XCTAssertTrue(underlyingError is DivideByZeroError)
            }

            expectation.fulfill()
        }, {
            return try self.sampleDivision(numerator: 6, denominator: 0)
        })

        wait(for: [expectation], timeout: defaultTimeoutSeconds)
    }

    func testSuccessfulVoidDispatch() {
        let expectation = XCTestExpectation.init()

        dispatcher.run(withCompletionHandler: { (result: StitchResult<Void>) in
            switch result {
            case .success:
                break
            case .failure:
                XCTFail("unexpected error")
            }

            expectation.fulfill()
        }, {
            return try self.sampleNoop(shouldThrow: false)
        })

        wait(for: [expectation], timeout: defaultTimeoutSeconds)
    }

    func testThrowingVoidDispatch() {
        let expectation = XCTestExpectation.init()

        dispatcher.run(withCompletionHandler: { (result: StitchResult<Void>) in
            switch result {
            case .success:
                XCTFail("expected an error and none was thrown")
            case .failure(let error):
                guard case .requestErrorFull(let underlyingError, let errorCode) = error else {
                    XCTFail("wrong error type")
                    return
                }
                XCTAssertEqual(StitchRequestErrorCode.unknownError, errorCode)
                XCTAssertTrue(underlyingError is ArbitraryError)
            }

            expectation.fulfill()
        }, {
            return try self.sampleNoop(shouldThrow: true)
        })

        wait(for: [expectation], timeout: defaultTimeoutSeconds)
    }
}
