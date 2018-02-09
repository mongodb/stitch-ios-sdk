import Foundation
import XCTest
import PromiseKit
import StitchLogger
@testable import StitchCore

internal extension StitchClient {
    func registerAndConfirm(email: String,
                            password: String,
                            withHarness harness: TestHarness) -> Promise<Void> {
        return self.register(email: email, password: password).then { _ in
            return harness.app.userRegistrations.sendConfirmation(toEmail: email)
        }.then { conf in
            return self.emailConfirm(token: conf.token,
                                     tokenId: conf.tokenId)
        }.asVoid()
    }
}

enum StitchTestError: Error {
    case unknown
}

internal class StitchTestCase: XCTestCase {
    internal private(set) var stitchClient: StitchClient!
    internal private(set) var harness: TestHarness!

    override open func setUp() {
        super.setUp()
        LogManager.minimumLogLevel = .debug
        self.harness = try! await(buildClientTestHarness())
        self.stitchClient = harness.stitchClient
        try! self.stitchClient.clearAuth()
    }

    override open func tearDown() {
        try! await(self.stitchClient.logout())
        try! self.stitchClient.clearAuth()
        try! await(self.harness.teardown())
    }
    
    @discardableResult
    func await<T>(_ promise: Promise<T>,
                  function: String = #function,
                  line: Int = #line) throws -> T {
        let exp = expectation(description: "#\(function)#\(line)")

        var computedReturn: (T?, Error?) = (nil, nil)

        promise.done {
            computedReturn.0 = $0
            exp.fulfill()
        }.catch { err in
            computedReturn.1 = err
            exp.fulfill()
        }

        wait(for: [exp], timeout: 10)
        guard let retVal = computedReturn.0 else {
            throw computedReturn.1 ?? StitchTestError.unknown
        }

        return retVal
    }
}
